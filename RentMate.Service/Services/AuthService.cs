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

        public AuthService(
            UserManager<ApplicationUser> userManager,
            RoleManager<IdentityRole> roleManager,
            IUnitOfWork unitOfWork,
            IAuditLogService auditLogService)
        {
            _userManager = userManager;
            _roleManager = roleManager;
            _unitOfWork = unitOfWork;
            _auditLogService = auditLogService;
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
                    "Email is already registered.");
            }

            string phoneNumber = dto.PhoneNumber.Trim();

            bool phoneExists = await _userManager.Users
                .AnyAsync(u => u.PhoneNumber == phoneNumber);

            if (phoneExists)
            {
                throw new ArgumentException(
                    "Phone number is already registered.");
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

            // Role "User" được tạo bởi DbSeeder của AdminSite
            if (await _roleManager.RoleExistsAsync("User"))
            {
                await _userManager.AddToRoleAsync(user, "User");
            }
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
                    RoleName = roles.Contains("Admin") ? "Admin" : roles.Contains("Manager") ? "Manager" : (roles.FirstOrDefault() ?? "User")
                }
            };
        }

        private async Task RejectLoginAsync(ApplicationUser? user, string ipAddress, string description = "Đăng nhập thất bại.")
        {
            await _auditLogService.RecordAsync("LoginFailed", "ApplicationUser", user?.Id, description, ipAddress, user?.Id);

            await _unitOfWork.SaveChangesAsync();
        }
    }
}
