using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.Interfaces;
using System.Net;

namespace RentMate.Service.Services
{
    // Quản lý tài khoản nội bộ (Admin, Manager). Khách hàng nằm ở CustomerService.
    public class AccountService : IAccountService
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuditLogService _auditLogService;
        private readonly IEmailService _emailService;

        private const string InvalidResetLinkMessage = "Link đặt lại mật khẩu không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu link mới.";

        public AccountService(UserManager<ApplicationUser> userManager, IUnitOfWork unitOfWork, IAuditLogService auditLogService, IEmailService emailService)
        {
            _userManager = userManager;
            _unitOfWork = unitOfWork;
            _auditLogService = auditLogService;
            _emailService = emailService;
        }

        public async Task<UserListViewModel> SearchAsync(string? searchTerm, bool? isActive, int page = 1)
        {
            // ApplicationUser kế thừa IdentityUser (khóa string) nên truy vấn qua UserManager
            var adminIds = (await _userManager.GetUsersInRoleAsync("Admin"))
                .Select(u => u.Id)
                .ToList();

            var managerIds = (await _userManager.GetUsersInRoleAsync("Manager"))
                .Select(u => u.Id)
                .ToList();

            var query = _userManager.Users
                .AsNoTracking()
                .Where(u => adminIds.Contains(u.Id) || managerIds.Contains(u.Id));

            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                string keyword = searchTerm.Trim();

                query = query.Where(u =>
                    u.FullName.Contains(keyword) ||
                    (u.Email != null && u.Email.Contains(keyword)) ||
                    (u.PhoneNumber != null && u.PhoneNumber.Contains(keyword)));
            }

            if (isActive.HasValue)
                query = query.Where(u => u.IsActive == isActive.Value);

            int totalCount = await query.CountAsync();
            const int pageSize = 10;
            page = Math.Clamp(page, 1, Math.Max(1, (totalCount + pageSize - 1) / pageSize));

            var users = await query
                .OrderByDescending(u => u.CreatedAt)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(u => new UserListItemViewModel
                {
                    Id = u.Id,
                    ConcurrencyStamp = u.ConcurrencyStamp,
                    FullName = u.FullName,
                    Email = u.Email ?? string.Empty,
                    PhoneNumber = u.PhoneNumber,
                    RoleName = adminIds.Contains(u.Id) ? "Admin" : "Manager",
                    IsActive = u.IsActive,
                    CreatedAt = u.CreatedAt
                })
                .ToListAsync();

            return new UserListViewModel
            {
                SearchTerm = searchTerm,
                IsActive = isActive,
                Users = users,
                Page = page, PageSize = pageSize, TotalCount = totalCount
            };
        }

        public async Task<UserListItemViewModel?> GetByIdAsync(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId);

            if (user == null)
                return null;

            return new UserListItemViewModel
            {
                Id = user.Id,
                FullName = user.FullName,
                Email = user.Email ?? string.Empty,
                PhoneNumber = user.PhoneNumber,
                AvatarUrl = user.AvatarUrl,
                RoleName = await GetRoleNameAsync(user),
                IsActive = user.IsActive,
                CreatedAt = user.CreatedAt
            };
        }

        // Admin tạo tài khoản Manager (hệ thống chỉ có 1 Admin duy nhất được seed sẵn)
        public async Task CreateAsync(UserCreateViewModel model, string actorUserId, string ipAddress)
        {
            if (string.IsNullOrWhiteSpace(model.FullName))
                throw new InvalidOperationException("Họ tên không được để trống.");

            string email = model.Email.Trim();
            string? phoneNumber = string.IsNullOrWhiteSpace(model.PhoneNumber) ? null : model.PhoneNumber.Trim();

            if (await _userManager.FindByEmailAsync(email) != null)
                throw new InvalidOperationException("Email đã tồn tại.");

            await EnsurePhoneNumberAvailableAsync(phoneNumber, null);

            var user = new ApplicationUser
            {
                FullName = model.FullName.Trim(),
                Email = email,
                UserName = email,
                PhoneNumber = phoneNumber,
                EmailConfirmed = true,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            var result = await _userManager.CreateAsync(user, model.Password);

            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join(" ", result.Errors.Select(e => e.Description)));

            await _userManager.AddToRoleAsync(user, "Manager");

            await _auditLogService.RecordAsync("CreateUser", "ApplicationUser", user.Id, $"Tạo tài khoản quản lý {user.Email}.", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        // Admin chỉnh sửa tài khoản Manager; mật khẩu mới để trống thì không đổi.
        // Mọi thay đổi trong 1 lần lưu được gộp thành 1 dòng nhật ký.
        public async Task UpdateUserAsync(UserEditViewModel model, string actorUserId, string ipAddress)
        {
            var user = await FindManagerAsync(model.Id);

            if (user.ConcurrencyStamp != model.ConcurrencyStamp)
                throw new InvalidOperationException(UserConcurrencyMessage);

            if (string.IsNullOrWhiteSpace(model.FullName))
                throw new InvalidOperationException("Họ tên không được để trống.");

            string fullName = model.FullName.Trim();
            string email = model.Email.Trim();
            string? phoneNumber = string.IsNullOrWhiteSpace(model.PhoneNumber) ? null : model.PhoneNumber.Trim();
            bool hasNewPassword = !string.IsNullOrWhiteSpace(model.NewPassword);

            if (hasNewPassword)
            {
                if (model.NewPassword != model.ConfirmPassword)
                    throw new InvalidOperationException("Mật khẩu xác nhận không khớp.");

                // Admin không biết mật khẩu cũ của Manager nên so bằng hash đang lưu
                if (await _userManager.CheckPasswordAsync(user, model.NewPassword!))
                    throw new InvalidOperationException("Mật khẩu mới phải khác mật khẩu hiện tại của tài khoản.");

                await EnsurePasswordValidAsync(user, model.NewPassword!);
            }

            var existingEmailUser = await _userManager.FindByEmailAsync(email);

            if (existingEmailUser != null && existingEmailUser.Id != user.Id)
                throw new InvalidOperationException("Email đã được sử dụng bởi tài khoản khác.");

            await EnsurePhoneNumberAvailableAsync(phoneNumber, user.Id);

            var changes = new List<string>();
            AddChange(changes, "họ tên", user.FullName, fullName);
            AddChange(changes, "email", user.Email, email);
            AddChange(changes, "số điện thoại", user.PhoneNumber, phoneNumber);

            if (changes.Count == 0 && !hasNewPassword)
                return;

            user.FullName = fullName;
            user.Email = email;
            user.UserName = email;
            user.PhoneNumber = phoneNumber;

            var result = await _userManager.UpdateAsync(user);

            // Người khác lưu đúng lúc giữa bước kiểm tra và bước lưu
            if (result.Errors.Any(e => e.Code == nameof(IdentityErrorDescriber.ConcurrencyFailure)))
                throw new InvalidOperationException(UserConcurrencyMessage);

            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join(" ", result.Errors.Select(e => e.Description)));

            if (hasNewPassword)
            {
                await SetPasswordAsync(user, model.NewPassword!);
                changes.Add("Đặt lại mật khẩu.");
            }

            await _auditLogService.RecordAsync("UpdateUser", "ApplicationUser", user.Id, $"Cập nhật tài khoản quản lý {user.Email}. {string.Join(" ", changes)}", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        private const string UserConcurrencyMessage = "Tài khoản này vừa được cập nhật ở nơi khác. Vui lòng tải lại trang rồi sửa lại.";

        public async Task<bool> SetActiveAsync(string id, bool isActive, string actorUserId, string ipAddress)
        {
            var user = await FindManagerAsync(id);

            // Trang của người bấm có thể đã cũ: người khác vừa khóa/mở trước đó
            if (user.IsActive == isActive)
                throw new InvalidOperationException(isActive ? "Tài khoản này đã được mở khóa trước đó." : "Tài khoản này đã bị khóa trước đó.");

            bool newIsActive = isActive;

            user.IsActive = newIsActive;

            if (newIsActive)
            {
                user.AccessFailedCount = 0;
                user.LockoutEnd = null;
            }

            await _auditLogService.RecordAsync(newIsActive ? "UnlockUser" : "LockUser", "ApplicationUser", user.Id, newIsActive ? $"Mở khóa tài khoản {user.Email}" : $"Khóa tài khoản {user.Email}", ipAddress, actorUserId);

            await _userManager.UpdateAsync(user);

            return newIsActive;
        }

        // Chỉ xóa được Manager chưa từng có thao tác nào (tạo nhầm),
        // còn lại phải khóa để giữ nguyên nhật ký "ai đã làm gì".
        public async Task DeleteAsync(string id, string actorUserId, string ipAddress)
        {
            var user = await FindManagerAsync(id);

            bool hasHistory = await _unitOfWork.AuditLogs
                .BuildQuery(log => log.UserId == user.Id)
                .AnyAsync();

            if (hasHistory)
                throw new InvalidOperationException("Tài khoản này đã có lịch sử thao tác nên không thể xóa. Hãy khóa tài khoản thay vì xóa.");

            await _auditLogService.RecordAsync("DeleteUser", "ApplicationUser", user.Id, $"Xóa tài khoản quản lý {user.Email}.", ipAddress, actorUserId);

            var result = await _userManager.DeleteAsync(user);

            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join(" ", result.Errors.Select(e => e.Description)));
        }

        public async Task UpdateProfileAsync(string userId, AccountProfileViewModel model, string ipAddress)
        {
            var user = await _userManager.FindByIdAsync(userId);

            if (user == null)
                throw new InvalidOperationException("Tài khoản không tồn tại.");

            if (string.IsNullOrWhiteSpace(model.FullName))
                throw new InvalidOperationException("Họ tên không được để trống.");

            string fullName = model.FullName.Trim();
            string email = model.Email.Trim();
            string? phoneNumber = string.IsNullOrWhiteSpace(model.PhoneNumber) ? null : model.PhoneNumber.Trim();

            var existingEmailUser = await _userManager.FindByEmailAsync(email);

            if (existingEmailUser != null && existingEmailUser.Id != user.Id)
                throw new InvalidOperationException("Email đã được sử dụng bởi tài khoản khác.");

            await EnsurePhoneNumberAvailableAsync(phoneNumber, user.Id);

            var changes = new List<string>();
            AddChange(changes, "họ tên", user.FullName, fullName);
            AddChange(changes, "email", user.Email, email);
            AddChange(changes, "số điện thoại", user.PhoneNumber, phoneNumber);

            if (changes.Count == 0)
                return;

            user.FullName = fullName;
            user.Email = email;
            user.UserName = email;
            user.PhoneNumber = phoneNumber;

            await _auditLogService.RecordAsync("UpdateProfile", "ApplicationUser", user.Id, $"Cập nhật thông tin cá nhân. {string.Join(" ", changes)}", ipAddress, user.Id);

            var result = await _userManager.UpdateAsync(user);

            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join(" ", result.Errors.Select(e => e.Description)));
        }

        // Trả về đường dẫn ảnh cũ để controller xóa file. avatarUrl = null nghĩa là gỡ ảnh.
        public async Task<string?> UpdateAvatarAsync(string userId, string? avatarUrl, string ipAddress)
        {
            var user = await _userManager.FindByIdAsync(userId);

            if (user == null)
                throw new InvalidOperationException("Tài khoản không tồn tại.");

            string? oldAvatarUrl = user.AvatarUrl;

            user.AvatarUrl = avatarUrl;

            await _auditLogService.RecordAsync("UpdateAvatar", "ApplicationUser", user.Id, avatarUrl == null ? "Gỡ ảnh đại diện." : "Đổi ảnh đại diện.", ipAddress, user.Id);

            var result = await _userManager.UpdateAsync(user);

            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join(" ", result.Errors.Select(e => e.Description)));

            return oldAvatarUrl;
        }

        public async Task ChangePasswordAsync(string userId, string oldPassword, string newPassword, string ipAddress)
        {
            var user = await _userManager.FindByIdAsync(userId);

            if (user == null)
                throw new InvalidOperationException("Tài khoản không tồn tại.");

            // Kiểm tra mật khẩu hiện tại trước để báo đúng lỗi khi người dùng gõ sai
            if (!await _userManager.CheckPasswordAsync(user, oldPassword))
                throw new InvalidOperationException("Mật khẩu hiện tại không đúng.");

            if (oldPassword == newPassword)
                throw new InvalidOperationException("Mật khẩu mới phải khác mật khẩu hiện tại.");

            var result = await _userManager.ChangePasswordAsync(user, oldPassword, newPassword);

            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join(" ", result.Errors.Select(e => e.Description)));

            await _auditLogService.RecordAsync("ChangePassword", "ApplicationUser", user.Id, "Tự đổi mật khẩu.", ipAddress, user.Id);

            await _unitOfWork.SaveChangesAsync();
        }

        // ===== QUÊN MẬT KHẨU (trang quản trị) =====

        // Không báo cho người nhập biết email có tồn tại hay không (tránh bị dò tài khoản quản trị):
        // chỉ âm thầm gửi link khi email thuộc Admin/Manager đang hoạt động.
        public async Task RequestPasswordResetAsync(string email, string resetPageUrl, string ipAddress)
        {
            var user = await _userManager.FindByEmailAsync(email.Trim());

            if (user == null || !user.IsActive || !await IsStaffAsync(user))
                return;

            // Chống spam hộp thư: mỗi tài khoản tối đa 1 email mỗi phút
            DateTime oneMinuteAgo = DateTime.UtcNow.AddMinutes(-1);

            bool sentRecently = await _unitOfWork.AuditLogs
                .BuildQuery(log => log.Action == "RequestPasswordReset" && log.EntityId == user.Id && log.CreatedAt >= oneMinuteAgo)
                .AnyAsync();

            if (sentRecently)
                return;

            // Token của Identity hết hạn theo TokenLifespan (cấu hình trong Program.cs)
            // và mất hiệu lực ngay khi mật khẩu đổi, nên link chỉ dùng được 1 lần
            string token = await _userManager.GeneratePasswordResetTokenAsync(user);
            string resetLink = $"{resetPageUrl}?userId={Uri.EscapeDataString(user.Id)}&token={Uri.EscapeDataString(token)}";

            string body =
                $"<p>Xin chào {WebUtility.HtmlEncode(user.FullName)},</p>" +
                "<p>Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản quản trị RentMate của bạn.</p>" +
                $"<p><a href=\"{WebUtility.HtmlEncode(resetLink)}\">Bấm vào đây để đặt mật khẩu mới</a></p>" +
                "<p>Link có hiệu lực trong 30 phút và chỉ dùng được một lần.</p>" +
                "<p>Nếu bạn không yêu cầu, hãy bỏ qua email này. Mật khẩu hiện tại của bạn vẫn giữ nguyên.</p>";

            await _emailService.SendAsync(user.Email!, "[RentMate] Đặt lại mật khẩu", body);

            await _auditLogService.RecordAsync("RequestPasswordReset", "ApplicationUser", user.Id, "Yêu cầu đặt lại mật khẩu qua email.", ipAddress, user.Id);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task<bool> IsPasswordResetLinkValidAsync(string userId, string token)
        {
            var user = await _userManager.FindByIdAsync(userId);

            return user != null && await IsResetTokenValidAsync(user, token);
        }

        public async Task ResetPasswordAsync(string userId, string token, string newPassword, string ipAddress)
        {
            var user = await _userManager.FindByIdAsync(userId);

            // Kiểm tra link trước mọi thứ khác: không cho người không có link dò mật khẩu hiện tại
            if (user == null || !await IsResetTokenValidAsync(user, token))
                throw new InvalidOperationException(InvalidResetLinkMessage);

            if (await _userManager.CheckPasswordAsync(user, newPassword))
                throw new InvalidOperationException("Mật khẩu mới phải khác mật khẩu hiện tại.");

            var result = await _userManager.ResetPasswordAsync(user, token, newPassword);

            if (!result.Succeeded)
            {
                if (result.Errors.Any(e => e.Code == "InvalidToken"))
                    throw new InvalidOperationException(InvalidResetLinkMessage);

                throw new InvalidOperationException(string.Join(" ", result.Errors.Select(e => e.Description)));
            }

            await _userManager.ResetAccessFailedCountAsync(user);
            await _userManager.SetLockoutEndDateAsync(user, null);

            await _auditLogService.RecordAsync("ResetPasswordByEmail", "ApplicationUser", user.Id, "Đặt lại mật khẩu qua link email.", ipAddress, user.Id);

            await _unitOfWork.SaveChangesAsync();

            // Báo cho chủ tài khoản biết, phòng khi không phải họ thực hiện.
            // Mật khẩu đã đổi xong nên gửi thất bại cũng không báo lỗi cho người dùng.
            try
            {
                string body =
                    $"<p>Xin chào {WebUtility.HtmlEncode(user.FullName)},</p>" +
                    $"<p>Mật khẩu tài khoản quản trị RentMate của bạn vừa được đặt lại lúc {DateTime.Now:HH:mm dd/MM/yyyy}.</p>" +
                    "<p>Nếu không phải bạn thực hiện, hãy liên hệ quản trị viên ngay.</p>";

                await _emailService.SendAsync(user.Email!, "[RentMate] Mật khẩu của bạn đã được thay đổi", body);
            }
            catch (InvalidOperationException)
            {
                // Lỗi gửi mail đã được ghi log trong SmtpEmailService
            }
        }

        private async Task<bool> IsResetTokenValidAsync(ApplicationUser user, string token)
        {
            if (string.IsNullOrWhiteSpace(token) || !user.IsActive || !await IsStaffAsync(user))
                return false;

            return await _userManager.VerifyUserTokenAsync(
                user,
                _userManager.Options.Tokens.PasswordResetTokenProvider,
                UserManager<ApplicationUser>.ResetPasswordTokenPurpose,
                token);
        }

        private async Task<bool> IsStaffAsync(ApplicationUser user)
        {
            var roles = await _userManager.GetRolesAsync(user);

            return roles.Contains("Admin") || roles.Contains("Manager");
        }

        private async Task<ApplicationUser> FindManagerAsync(string id)
        {
            var user = await _userManager.FindByIdAsync(id);

            if (user == null)
                throw new InvalidOperationException("Tài khoản không tồn tại.");

            if (!await _userManager.IsInRoleAsync(user, "Manager"))
                throw new InvalidOperationException("Chỉ được thao tác trên tài khoản Quản lý. Thông tin của bạn hãy sửa ở mục Thông tin tài khoản.");

            return user;
        }

        private async Task<string> GetRoleNameAsync(ApplicationUser user)
        {
            var roles = await _userManager.GetRolesAsync(user);

            if (roles.Contains("Admin"))
                return "Admin";

            if (roles.Contains("Manager"))
                return "Manager";

            return "User";
        }

        private async Task SetPasswordAsync(ApplicationUser user, string newPassword)
        {
            // Kiểm tra trước để không rơi vào cảnh đã gỡ mật khẩu cũ mà mật khẩu mới lại bị từ chối
            await EnsurePasswordValidAsync(user, newPassword);

            var removeResult = await _userManager.RemovePasswordAsync(user);

            if (!removeResult.Succeeded)
                throw new InvalidOperationException(string.Join(" ", removeResult.Errors.Select(e => e.Description)));

            var addResult = await _userManager.AddPasswordAsync(user, newPassword);

            if (!addResult.Succeeded)
                throw new InvalidOperationException(string.Join(" ", addResult.Errors.Select(e => e.Description)));

            await _userManager.ResetAccessFailedCountAsync(user);
            await _userManager.SetLockoutEndDateAsync(user, null);
        }

        private async Task EnsurePasswordValidAsync(ApplicationUser user, string password)
        {
            var errors = new List<string>();

            foreach (var validator in _userManager.PasswordValidators)
            {
                var result = await validator.ValidateAsync(_userManager, user, password);

                if (!result.Succeeded)
                    errors.AddRange(result.Errors.Select(e => e.Description));
            }

            if (errors.Count > 0)
                throw new InvalidOperationException(string.Join(" ", errors));
        }

        private async Task EnsurePhoneNumberAvailableAsync(string? phoneNumber, string? excludeUserId)
        {
            if (phoneNumber == null)
                return;

            bool phoneExists = await _userManager.Users
                .AnyAsync(u => u.PhoneNumber == phoneNumber && u.Id != excludeUserId);

            if (phoneExists)
                throw new InvalidOperationException("Số điện thoại đã được sử dụng bởi tài khoản khác.");
        }

        private static void AddChange(List<string> changes, string label, string? oldValue, string? newValue)
        {
            if (oldValue == newValue)
                return;

            changes.Add($"Thay đổi {label} từ {oldValue ?? "(trống)"} sang {newValue ?? "(trống)"}.");
        }
    }
}
