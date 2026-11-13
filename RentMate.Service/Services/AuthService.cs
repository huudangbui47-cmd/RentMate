using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Service.DTOs;
using RentMate.Service.DTOs.Auth;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class AuthService : IAuthService
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly RoleManager<IdentityRole> _roleManager;
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuditLogService _auditLogService;
        private readonly IEmailService _emailService;

        // Mục đích riêng cho mã quên mật khẩu của khách (mã 6 số gửi qua email)
        private const string CustomerResetCodePurpose = "CustomerResetPasswordCode";

        public AuthService(
            UserManager<ApplicationUser> userManager,
            RoleManager<IdentityRole> roleManager,
            IUnitOfWork unitOfWork,
            IAuditLogService auditLogService,
            IEmailService emailService)
        {
            _userManager = userManager;
            _roleManager = roleManager;
            _unitOfWork = unitOfWork;
            _auditLogService = auditLogService;
            _emailService = emailService;
        }

        // =========================
        // REGISTER
        // =========================
        public async Task RegisterAsync(RegisterDto dto)
        {
            var existingUser =
                await _userManager.FindByEmailAsync(dto.Email);

            if (existingUser != null)
            {
                throw new ArgumentException(
                    "Email này đã được đăng ký.");
            }

            string phoneNumber = dto.PhoneNumber.Trim();

            bool phoneExists = await _userManager.Users
                .AnyAsync(u => u.PhoneNumber == phoneNumber);

            if (phoneExists)
            {
                throw new ArgumentException(
                    "Số điện thoại này đã được đăng ký.");
            }

            var user = new ApplicationUser
            {
                FullName = dto.FullName.Trim(),
                Email = dto.Email.Trim(),
                UserName = dto.Email.Trim(),
                PhoneNumber = dto.PhoneNumber.Trim(),
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            var result =
                await _userManager.CreateAsync(
                    user,
                    dto.Password);

            if (!result.Succeeded)
            {
                var errors = string.Join(
                    "; ",
                    result.Errors.Select(e => e.Description));

                throw new ArgumentException(errors);
            }

            // Role "User" thường do DbSeeder của AdminSite tạo. Nếu Api chạy trước AdminSite
            // thì tạo luôn ở đây, để không sinh ra tài khoản không có role.
            if (!await _roleManager.RoleExistsAsync("User"))
            {
                await _roleManager.CreateAsync(new IdentityRole("User"));
            }

            var roleResult = await _userManager.AddToRoleAsync(user, "User");

            if (!roleResult.Succeeded)
            {
                throw new ArgumentException(string.Join(
                    "; ",
                    roleResult.Errors.Select(e => e.Description)));
            }
        }

        // =========================
        // KIỂM TRA PHIÊN ĐĂNG NHẬP
        // =========================

        // Phiên (cookie hoặc JWT) chỉ còn hợp lệ khi tài khoản vẫn hoạt động và SecurityStamp chưa đổi.
        // SecurityStamp tự đổi khi mật khẩu được đổi hoặc đặt lại, nên các phiên cũ bị đăng xuất.
        public async Task<bool> IsSessionValidAsync(string userId, string? securityStamp)
        {
            if (string.IsNullOrEmpty(securityStamp))
                return false;

            var user = await _userManager.FindByIdAsync(userId);

            return user != null
                && user.IsActive
                && user.SecurityStamp == securityStamp;
        }

        public async Task<string?> GetSecurityStampAsync(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId);

            return user?.SecurityStamp;
        }

        // =========================
        // LOGIN
        // =========================
        public async Task<LoginResult> LoginAsync(string email, string password, string ipAddress, string[]? allowedRoles = null)
        {
            string normalizedEmail = email.Trim();

            // 1. Tìm tài khoản theo email
            var user = await _userManager.FindByEmailAsync(normalizedEmail);

            if (user == null)
            {
                await RejectLoginAsync(null, ipAddress);

                return new LoginResult
                {
                    Status = LoginStatus.InvalidCredentials
                };
            }

            if (!user.IsActive)
            {
                await RejectLoginAsync(user, ipAddress);

                return new LoginResult
                {
                    Status = LoginStatus.Inactive
                };
            }

            // 2. Tài khoản còn trong thời gian khóa tạm
            if (await _userManager.IsLockedOutAsync(user))
            {
                await RejectLoginAsync(user, ipAddress);

                return new LoginResult
                {
                    Status = LoginStatus.TemporarilyLocked,
                    LockoutEnd = user.LockoutEnd
                };
            }

            // 3. Kiểm tra mật khẩu (Identity tự khóa tạm sau 5 lần sai)
            bool passwordIsCorrect = await _userManager.CheckPasswordAsync(user, password);

            if (!passwordIsCorrect)
            {
                await _userManager.AccessFailedAsync(user);

                await RejectLoginAsync(user, ipAddress);

                if (await _userManager.IsLockedOutAsync(user))
                {
                    return new LoginResult
                    {
                        Status = LoginStatus.TemporarilyLocked,
                        LockoutEnd = user.LockoutEnd
                    };
                }

                return new LoginResult
                {
                    Status = LoginStatus.InvalidCredentials
                };
            }

            // 4. Đúng mật khẩu nhưng không có quyền vào nơi đang đăng nhập (vd. khách vào trang quản trị)
            await _userManager.ResetAccessFailedCountAsync(user);

            var roles = await _userManager.GetRolesAsync(user);

            if (allowedRoles != null && !roles.Any(allowedRoles.Contains))
            {
                await RejectLoginAsync(user, ipAddress, "Đăng nhập thất bại: tài khoản không có quyền truy cập.");

                return new LoginResult
                {
                    Status = LoginStatus.AccessDenied
                };
            }

            // 5. Đăng nhập thành công
            await _auditLogService.RecordAsync("LoginSuccess", "ApplicationUser", user.Id, "Đăng nhập thành công.", ipAddress, user.Id);

            await _unitOfWork.SaveChangesAsync();

            return new LoginResult
            {
                Status = LoginStatus.Success,

                User = new AuthenticatedUser
                {
                    Id = user.Id,
                    FullName = user.FullName,
                    Email = user.Email ?? string.Empty,
                    AvatarUrl = user.AvatarUrl,
                    SecurityStamp = user.SecurityStamp ?? string.Empty,
                    RoleName = roles.Contains("Admin") ? "Admin" : roles.Contains("Manager") ? "Manager" : (roles.FirstOrDefault() ?? "User")
                }
            };
        }

        // =========================
        // TÀI KHOẢN KHÁCH (app)
        // =========================
        public async Task<ProfileDto?> GetProfileAsync(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId);

            if (user == null)
                return null;

            return new ProfileDto
            {
                UserId = user.Id,
                FullName = user.FullName,
                Email = user.Email ?? string.Empty,
                PhoneNumber = user.PhoneNumber,
                Address = user.Address,
                CreatedAt = user.CreatedAt
            };
        }

        public async Task UpdateProfileAsync(string userId, UpdateProfileDto dto, string ipAddress)
        {
            var user = await _userManager.FindByIdAsync(userId)
                ?? throw new ArgumentException("Tài khoản không tồn tại.");

            string phoneNumber = dto.PhoneNumber.Trim();

            if (await _userManager.Users.AnyAsync(u => u.Id != userId && u.PhoneNumber == phoneNumber))
                throw new ArgumentException("Số điện thoại này đã được tài khoản khác sử dụng.");

            user.FullName = dto.FullName.Trim();
            user.PhoneNumber = phoneNumber;
            user.Address = string.IsNullOrWhiteSpace(dto.Address) ? null : dto.Address.Trim();

            var result = await _userManager.UpdateAsync(user);

            if (!result.Succeeded)
                throw new ArgumentException(string.Join(" ", result.Errors.Select(e => e.Description)));

            await _auditLogService.RecordAsync("CustomerUpdateProfile", "Customer", user.Id, "Khách tự sửa thông tin tài khoản trên app.", ipAddress, user.Id);

            await _unitOfWork.SaveChangesAsync();
        }

        // Đổi mật khẩu làm SecurityStamp thay đổi nên mọi token cũ (kể cả máy đang dùng) hết hiệu lực.
        // Trả về thông tin mới để controller cấp token mới cho máy đang dùng.
        public async Task<AuthenticatedUser> ChangePasswordAsync(string userId, ChangePasswordDto dto, string ipAddress)
        {
            var user = await _userManager.FindByIdAsync(userId)
                ?? throw new ArgumentException("Tài khoản không tồn tại.");

            if (dto.CurrentPassword == dto.NewPassword)
                throw new ArgumentException("Mật khẩu mới phải khác mật khẩu hiện tại.");

            var result = await _userManager.ChangePasswordAsync(user, dto.CurrentPassword, dto.NewPassword);

            if (!result.Succeeded)
                throw new ArgumentException(string.Join(" ", result.Errors.Select(e => e.Description)));

            await _auditLogService.RecordAsync("CustomerChangePassword", "Customer", user.Id, "Khách đổi mật khẩu trên app.", ipAddress, user.Id);

            await _unitOfWork.SaveChangesAsync();

            return await ToAuthenticatedUserAsync(user);
        }

        // Không báo email có tồn tại hay không (tránh bị dò tài khoản): email lạ thì im lặng bỏ qua.
        public async Task RequestPasswordResetCodeAsync(string email, string ipAddress)
        {
            var user = await _userManager.FindByEmailAsync(email.Trim());

            // Tài khoản quản trị đặt lại mật khẩu bằng link trên trang quản trị
            if (user == null || !user.IsActive || !await _userManager.IsInRoleAsync(user, "User"))
                return;

            // Chống spam hộp thư: mỗi tài khoản tối đa 1 mã mỗi phút
            DateTime oneMinuteAgo = DateTime.UtcNow.AddMinutes(-1);

            bool sentRecently = await _unitOfWork.AuditLogs
                .BuildQuery(log => log.Action == "CustomerRequestPasswordReset" && log.EntityId == user.Id && log.CreatedAt >= oneMinuteAgo)
                .AnyAsync();

            if (sentRecently)
                throw new ArgumentException("Mã vừa được gửi. Vui lòng kiểm tra email hoặc đợi 1 phút rồi gửi lại.");

            // Mã 6 số của Identity, hết hạn sau khoảng 10 phút và mất hiệu lực khi mật khẩu đổi
            string code = await _userManager.GenerateUserTokenAsync(user, TokenOptions.DefaultEmailProvider, CustomerResetCodePurpose);

            string body =
                $"<p>Xin chào {System.Net.WebUtility.HtmlEncode(user.FullName)},</p>" +
                "<p>Mã đặt lại mật khẩu RentMate của bạn là:</p>" +
                $"<p style=\"font-size:28px;font-weight:bold;letter-spacing:6px\">{code}</p>" +
                "<p>Mã có hiệu lực trong khoảng 10 phút. Không chia sẻ mã này cho bất kỳ ai.</p>" +
                "<p>Nếu bạn không yêu cầu, hãy bỏ qua email này. Mật khẩu hiện tại vẫn giữ nguyên.</p>";

            // Lỗi gửi mail (InvalidOperationException) để controller báo cho người dùng
            await _emailService.SendAsync(user.Email!, "[RentMate] Mã đặt lại mật khẩu", body);

            await _auditLogService.RecordAsync("CustomerRequestPasswordReset", "Customer", user.Id, "Gửi mã đặt lại mật khẩu qua email.", ipAddress, user.Id);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task ResetPasswordWithCodeAsync(ResetPasswordWithCodeDto dto, string ipAddress)
        {
            const string invalidCode = "Mã xác nhận không đúng hoặc đã hết hạn.";

            var user = await _userManager.FindByEmailAsync(dto.Email.Trim());

            if (user == null || !user.IsActive || !await _userManager.IsInRoleAsync(user, "User"))
                throw new ArgumentException(invalidCode);

            // Nhập sai mã nhiều lần cũng bị khóa tạm như đăng nhập sai, để không dò được mã 6 số
            if (await _userManager.IsLockedOutAsync(user))
                throw new ArgumentException("Bạn nhập sai quá nhiều lần. Vui lòng thử lại sau 5 phút.");

            bool codeValid = await _userManager.VerifyUserTokenAsync(user, TokenOptions.DefaultEmailProvider, CustomerResetCodePurpose, dto.Code.Trim());

            if (!codeValid)
            {
                await _userManager.AccessFailedAsync(user);
                throw new ArgumentException(invalidCode);
            }

            // Mã đúng: dùng token đặt lại mật khẩu chuẩn của Identity (kiểm tra độ mạnh mật khẩu, đổi SecurityStamp)
            string resetToken = await _userManager.GeneratePasswordResetTokenAsync(user);

            var result = await _userManager.ResetPasswordAsync(user, resetToken, dto.NewPassword);

            if (!result.Succeeded)
                throw new ArgumentException(string.Join(" ", result.Errors.Select(e => e.Description)));

            await _userManager.ResetAccessFailedCountAsync(user);

            await _auditLogService.RecordAsync("CustomerResetPassword", "Customer", user.Id, "Khách đặt lại mật khẩu bằng mã gửi qua email.", ipAddress, user.Id);

            await _unitOfWork.SaveChangesAsync();
        }

        private async Task<AuthenticatedUser> ToAuthenticatedUserAsync(ApplicationUser user)
        {
            var roles = await _userManager.GetRolesAsync(user);

            return new AuthenticatedUser
            {
                Id = user.Id,
                FullName = user.FullName,
                Email = user.Email ?? string.Empty,
                AvatarUrl = user.AvatarUrl,
                SecurityStamp = user.SecurityStamp ?? string.Empty,
                RoleName = roles.Contains("Admin") ? "Admin" : roles.Contains("Manager") ? "Manager" : (roles.FirstOrDefault() ?? "User")
            };
        }

        private async Task RejectLoginAsync(ApplicationUser? user, string ipAddress, string description = "Đăng nhập thất bại.")
        {
            await _auditLogService.RecordAsync("LoginFailed", "ApplicationUser", user?.Id, description, ipAddress, user?.Id);

            await _unitOfWork.SaveChangesAsync();
        }
    }
}
