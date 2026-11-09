using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.Interfaces;
using System.Security.Cryptography;

namespace RentMate.Service.Services
{
    // Khách hàng là tài khoản role "User" (vừa thuê vừa cho thuê được).
    // Không có chức năng xóa khách hàng: chỉ khóa, để giữ lịch sử giao dịch
    // và để email/SĐT cũ không đăng ký lại được.
    public class CustomerService : ICustomerService
    {
        // Đơn chưa kết thúc: còn tiền cọc hoặc đồ chưa trả xong
        private static readonly RentalStatus[] UnfinishedRentalStatuses =
        {
            RentalStatus.Pending,
            RentalStatus.Approved,
            RentalStatus.WaitingForPickup,
            RentalStatus.Rented,
            RentalStatus.Returned,
            RentalStatus.Overdue
        };

        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuditLogService _auditLogService;

        public CustomerService(UserManager<ApplicationUser> userManager, IUnitOfWork unitOfWork, IAuditLogService auditLogService)
        {
            _userManager = userManager;
            _unitOfWork = unitOfWork;
            _auditLogService = auditLogService;
        }

        public async Task<CustomerListViewModel> SearchAsync(string? searchTerm, bool? isActive, int page = 1)
        {
            var customerIds = (await _userManager.GetUsersInRoleAsync("User"))
                .Select(u => u.Id)
                .ToList();

            var query = _userManager.Users
                .AsNoTracking()
                .Where(u => customerIds.Contains(u.Id));

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

            var customers = await query
                .OrderByDescending(u => u.CreatedAt)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(u => new CustomerViewModel
                {
                    Id = u.Id,
                    ConcurrencyStamp = u.ConcurrencyStamp,
                    FullName = u.FullName,
                    Email = u.Email ?? string.Empty,
                    PhoneNumber = u.PhoneNumber ?? string.Empty,
                    Address = u.Address,
                    IsActive = u.IsActive,
                    CreatedAt = u.CreatedAt,
                    ItemCount = u.Items.Count,
                    RentalCount = u.Rentals.Count
                })
                .ToListAsync();

            return new CustomerListViewModel
            {
                SearchTerm = searchTerm,
                IsActive = isActive,
                Customers = customers,
                Page = page, PageSize = pageSize, TotalCount = totalCount
            };
        }

        public async Task<CustomerViewModel?> GetByIdAsync(string id)
        {
            var user = await _userManager.FindByIdAsync(id);

            if (user == null || !await _userManager.IsInRoleAsync(user, "User"))
                return null;

            return new CustomerViewModel
            {
                Id = user.Id,
                FullName = user.FullName,
                Email = user.Email ?? string.Empty,
                PhoneNumber = user.PhoneNumber ?? string.Empty,
                Address = user.Address,
                IsActive = user.IsActive,
                CreatedAt = user.CreatedAt
            };
        }

        public async Task<string> CreateAsync(CustomerViewModel model, string actorUserId, string ipAddress)
        {
            string email = model.Email.Trim();
            string phoneNumber = model.PhoneNumber.Trim();

            if (await _userManager.FindByEmailAsync(email) != null)
                throw new InvalidOperationException("Email đã tồn tại.");

            await EnsurePhoneNumberAvailableAsync(phoneNumber, null);

            var customer = new ApplicationUser
            {
                FullName = model.FullName.Trim(),
                Email = email,
                UserName = email,
                PhoneNumber = phoneNumber,
                Address = string.IsNullOrWhiteSpace(model.Address) ? null : model.Address.Trim(),
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            string temporaryPassword = GenerateTemporaryPassword();

            var result = await _userManager.CreateAsync(customer, temporaryPassword);

            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join(" ", result.Errors.Select(e => e.Description)));

            await _userManager.AddToRoleAsync(customer, "User");

            await _auditLogService.RecordAsync("CreateCustomer", "Customer", customer.Id, $"Thêm khách hàng {customer.FullName} ({customer.Email}).", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();

            return temporaryPassword;
        }

        // Mọi thay đổi trong 1 lần lưu được gộp thành 1 dòng nhật ký
        public async Task UpdateAsync(CustomerViewModel model, string actorUserId, string ipAddress)
        {
            var customer = await FindCustomerAsync(model.Id);

            if (customer.ConcurrencyStamp != model.ConcurrencyStamp)
                throw new InvalidOperationException(ConcurrencyMessage);

            string fullName = model.FullName.Trim();
            string email = model.Email.Trim();
            string phoneNumber = model.PhoneNumber.Trim();
            string? address = string.IsNullOrWhiteSpace(model.Address) ? null : model.Address.Trim();

            var existingEmailUser = await _userManager.FindByEmailAsync(email);

            if (existingEmailUser != null && existingEmailUser.Id != customer.Id)
                throw new InvalidOperationException("Email đã được sử dụng bởi tài khoản khác.");

            await EnsurePhoneNumberAvailableAsync(phoneNumber, customer.Id);

            var changes = new List<string>();
            AddChange(changes, "họ tên", customer.FullName, fullName);
            AddChange(changes, "email", customer.Email, email);
            AddChange(changes, "số điện thoại", customer.PhoneNumber, phoneNumber);
            AddChange(changes, "địa chỉ", customer.Address, address);

            if (changes.Count == 0)
                return;

            customer.FullName = fullName;
            customer.Email = email;
            customer.UserName = email;
            customer.PhoneNumber = phoneNumber;
            customer.Address = address;

            await _auditLogService.RecordAsync("UpdateCustomer", "Customer", customer.Id, $"Cập nhật khách hàng {customer.FullName}. {string.Join(" ", changes)}", ipAddress, actorUserId);

            var result = await _userManager.UpdateAsync(customer);

            // Người khác lưu đúng lúc giữa bước kiểm tra và bước lưu
            if (result.Errors.Any(e => e.Code == nameof(IdentityErrorDescriber.ConcurrencyFailure)))
                throw new InvalidOperationException(ConcurrencyMessage);

            if (!result.Succeeded)
                throw new InvalidOperationException(string.Join(" ", result.Errors.Select(e => e.Description)));
        }

        private const string ConcurrencyMessage = "Khách hàng này vừa được cập nhật ở nơi khác. Vui lòng tải lại trang rồi sửa lại.";

        // Nhân viên không tự đặt mật khẩu cho khách: hệ thống sinh mật khẩu tạm,
        // nhật ký chỉ ghi nhận hành động, không lưu mật khẩu.
        public async Task<string> ResetPasswordAsync(string id, string actorUserId, string ipAddress)
        {
            var customer = await FindCustomerAsync(id);

            string temporaryPassword = GenerateTemporaryPassword();

            var removeResult = await _userManager.RemovePasswordAsync(customer);

            if (!removeResult.Succeeded)
                throw new InvalidOperationException(string.Join(" ", removeResult.Errors.Select(e => e.Description)));

            var addResult = await _userManager.AddPasswordAsync(customer, temporaryPassword);

            if (!addResult.Succeeded)
                throw new InvalidOperationException(string.Join(" ", addResult.Errors.Select(e => e.Description)));

            await _userManager.ResetAccessFailedCountAsync(customer);
            await _userManager.SetLockoutEndDateAsync(customer, null);

            await _auditLogService.RecordAsync("ResetPassword", "Customer", customer.Id, $"Đặt lại mật khẩu cho khách hàng {customer.FullName} ({customer.Email}).", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();

            return temporaryPassword;
        }

        public async Task<bool> SetActiveAsync(string id, bool isActive, string actorUserId, string ipAddress)
        {
            var customer = await FindCustomerAsync(id);

            // Trang của người bấm có thể đã cũ: người khác vừa khóa/mở trước đó
            if (customer.IsActive == isActive)
                throw new InvalidOperationException(isActive ? "Khách hàng này đã được mở khóa trước đó." : "Khách hàng này đã bị khóa trước đó.");

            bool newIsActive = isActive;

            if (!newIsActive)
            {
                // Khách đang thuê đồ hoặc đang có người thuê đồ của mình thì chưa được khóa
                bool hasUnfinishedRentals = await _unitOfWork.Rentals
                    .BuildQuery(r =>
                        (r.RenterId == customer.Id || r.Item.OwnerId == customer.Id) &&
                        UnfinishedRentalStatuses.Contains(r.Status))
                    .AnyAsync();

                if (hasUnfinishedRentals)
                    throw new InvalidOperationException("Khách hàng đang có đơn thuê chưa hoàn tất nên chưa thể khóa.");
            }

            customer.IsActive = newIsActive;

            if (newIsActive)
            {
                customer.AccessFailedCount = 0;
                customer.LockoutEnd = null;
            }

            await _auditLogService.RecordAsync(newIsActive ? "UnlockUser" : "LockUser", "Customer", customer.Id, newIsActive ? $"Mở khóa khách hàng {customer.FullName} ({customer.Email})." : $"Khóa khách hàng {customer.FullName} ({customer.Email}).", ipAddress, actorUserId);

            await _userManager.UpdateAsync(customer);

            return newIsActive;
        }

        private async Task<ApplicationUser> FindCustomerAsync(string id)
        {
            var user = await _userManager.FindByIdAsync(id);

            if (user == null || !await _userManager.IsInRoleAsync(user, "User"))
                throw new InvalidOperationException("Khách hàng không tồn tại.");

            return user;
        }

        private async Task EnsurePhoneNumberAvailableAsync(string phoneNumber, string? excludeUserId)
        {
            bool phoneExists = await _userManager.Users
                .AnyAsync(u => u.PhoneNumber == phoneNumber && u.Id != excludeUserId);

            if (phoneExists)
                throw new InvalidOperationException("Số điện thoại đã được sử dụng bởi tài khoản khác.");
        }

        // Đủ yêu cầu mặc định của Identity: chữ hoa, chữ thường, số, ký tự đặc biệt
        private static string GenerateTemporaryPassword()
        {
            return $"Rm@{RandomNumberGenerator.GetInt32(100000, 1000000)}x";
        }

        private static void AddChange(List<string> changes, string label, string? oldValue, string? newValue)
        {
            if (oldValue == newValue)
                return;

            changes.Add($"Thay đổi {label} từ {oldValue ?? "(trống)"} sang {newValue ?? "(trống)"}.");
        }
    }
}
