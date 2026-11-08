using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.AdminSite.Infrastructure.Storage;
using RentMate.Core.Enums;
using RentMate.Core.ViewModels;
using RentMate.Service.Interfaces;
using System.Security.Claims;

namespace RentMate.AdminSite.Controllers
{
    public class AccountController : Controller
    {
        private readonly IAuthService _authService;
        private readonly IAccountService _accountService;
        private readonly IFileStorageService _fileStorageService;

        public AccountController(IAuthService authService, IAccountService accountService, IFileStorageService fileStorageService)
        {
            _authService = authService;
            _accountService = accountService;
            _fileStorageService = fileStorageService;
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult Login()
        {
            if (User.Identity?.IsAuthenticated == true)
            {
                return RedirectToAction("Index", "Dashboard", new { area = "Management" });
            }

            return View(new LoginViewModel());
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(LoginViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            string ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Không xác định";

            var result = await _authService.LoginAsync(model.Email, model.Password, ipAddress);

            if (result.Status == LoginStatus.InvalidCredentials)
            {
                ModelState.AddModelError(string.Empty, "Email hoặc mật khẩu không đúng.");

                return View(model);
            }

            if (result.Status == LoginStatus.Inactive)
            {
                ModelState.AddModelError(string.Empty, "Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.");

                return View(model);
            }

            if (result.Status == LoginStatus.TemporarilyLocked)
            {
                int remainingMinutes = 5;

                if (result.LockoutEnd.HasValue)
                {
                    remainingMinutes = Math.Max(1, (int)Math.Ceiling((result.LockoutEnd.Value - DateTimeOffset.UtcNow).TotalMinutes));
                }

                ModelState.AddModelError(string.Empty, $"Tài khoản đang bị khóa tạm thời. Vui lòng thử lại sau khoảng {remainingMinutes} phút.");

                return View(model);
            }

            if (result.Status != LoginStatus.Success || result.User == null)
            {
                ModelState.AddModelError(string.Empty, "Không thể đăng nhập. Vui lòng thử lại.");

                return View(model);
            }

            var user = result.User;

            // Trang quản trị chỉ dành cho Admin và Manager
            if (user.RoleName != "Admin" && user.RoleName != "Manager")
            {
                ModelState.AddModelError(string.Empty, "Tài khoản không có quyền truy cập trang quản trị.");

                return View(model);
            }

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id),

                new Claim(ClaimTypes.Name, user.FullName),

                new Claim(ClaimTypes.Email, user.Email),

                new Claim(ClaimTypes.Role, user.RoleName)
            };

            if (!string.IsNullOrEmpty(user.AvatarUrl))
            {
                claims.Add(new Claim("AvatarUrl", user.AvatarUrl));
            }

            var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

            var principal = new ClaimsPrincipal(identity);

            var authenticationProperties = new AuthenticationProperties
            {
                IsPersistent = model.RememberMe,
                AllowRefresh = true
            };

            if (model.RememberMe)
            {
                authenticationProperties.ExpiresUtc = DateTimeOffset.UtcNow.AddDays(7);
            }

            await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal, authenticationProperties);

            return RedirectToAction("Index", "Dashboard", new { area = "Management" });
        }

        [HttpPost]
        [Authorize]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

            return RedirectToAction(nameof(Login));
        }

        [HttpGet]
        [AllowAnonymous]
        public IActionResult AccessDenied()
        {
            return View();
        }

        [HttpGet]
        [Authorize]
        public async Task<IActionResult> Profile()
        {
            string userId = GetCurrentUserId();

            var user = await _accountService.GetByIdAsync(userId);

            if (user == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy thông tin tài khoản."
                });
            }

            return Ok(new
            {
                fullName = user.FullName,
                email = user.Email,
                phoneNumber = user.PhoneNumber,
                avatarUrl = user.AvatarUrl,
                roleName = user.RoleDisplayName
            });
        }

        [HttpPost]
        [Authorize]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> UpdateProfile(AccountProfileViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(new
                {
                    message = GetFirstModelError()
                });
            }

            try
            {
                string userId = GetCurrentUserId();
                string ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Không xác định";

                await _accountService.UpdateProfileAsync(userId, model, ipAddress);

                var updatedUser = await _accountService.GetByIdAsync(userId);

                if (updatedUser == null)
                {
                    return NotFound(new
                    {
                        message = "Không tìm thấy thông tin tài khoản."
                    });
                }

                await RefreshSignInAsync(updatedUser);

                return Ok(new
                {
                    message = "Cập nhật thông tin tài khoản thành công.",
                    fullName = updatedUser.FullName,
                    email = updatedUser.Email,
                    roleName = updatedUser.RoleDisplayName
                });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new
                {
                    message = ex.Message
                });
            }
        }

        [HttpPost]
        [Authorize]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ChangePasswordAjax(ChangePasswordViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(new
                {
                    message = GetFirstModelError()
                });
            }

            if (model.NewPassword == model.OldPassword)
            {
                return BadRequest(new
                {
                    message = "Mật khẩu mới phải khác mật khẩu hiện tại."
                });
            }

            try
            {
                string userId = GetCurrentUserId();
                string ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Không xác định";

                await _accountService.ChangePasswordAsync(userId, model.OldPassword, model.NewPassword, ipAddress);

                return Ok(new
                {
                    message = "Đổi mật khẩu thành công."
                });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new
                {
                    message = ex.Message
                });
            }
        }

        [HttpPost]
        [Authorize]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> UploadAvatar(IFormFile? avatar)
        {
            if (avatar == null || avatar.Length == 0)
            {
                return BadRequest(new
                {
                    message = "Vui lòng chọn ảnh."
                });
            }

            string? imageError = _fileStorageService.ValidateImage(avatar);

            if (imageError != null)
            {
                return BadRequest(new
                {
                    message = imageError
                });
            }

            string avatarUrl = await _fileStorageService.SaveAsync(avatar, "uploads/avatars");

            try
            {
                string userId = GetCurrentUserId();
                string ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Không xác định";

                string? oldAvatarUrl = await _accountService.UpdateAvatarAsync(userId, avatarUrl, ipAddress);

                _fileStorageService.Delete(oldAvatarUrl);

                return await AvatarUpdatedAsync(userId, "Cập nhật ảnh đại diện thành công.");
            }
            catch (InvalidOperationException ex)
            {
                _fileStorageService.Delete(avatarUrl);

                return BadRequest(new
                {
                    message = ex.Message
                });
            }
        }

        [HttpPost]
        [Authorize]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> RemoveAvatar()
        {
            try
            {
                string userId = GetCurrentUserId();
                string ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Không xác định";

                string? oldAvatarUrl = await _accountService.UpdateAvatarAsync(userId, null, ipAddress);

                _fileStorageService.Delete(oldAvatarUrl);

                return await AvatarUpdatedAsync(userId, "Đã gỡ ảnh đại diện.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new
                {
                    message = ex.Message
                });
            }
        }

        // Cập nhật lại cookie để avatar ở sidebar đổi theo ngay
        private async Task<IActionResult> AvatarUpdatedAsync(string userId, string message)
        {
            var updatedUser = await _accountService.GetByIdAsync(userId);

            if (updatedUser == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy thông tin tài khoản."
                });
            }

            await RefreshSignInAsync(updatedUser);

            return Ok(new
            {
                message,
                avatarUrl = updatedUser.AvatarUrl,
                fullName = updatedUser.FullName
            });
        }

        private string GetCurrentUserId()
        {
            string? value = User.FindFirstValue(ClaimTypes.NameIdentifier);

            if (string.IsNullOrEmpty(value))
            {
                throw new InvalidOperationException("Không xác định được người dùng hiện tại.");
            }

            return value;
        }

        private string GetFirstModelError()
        {
            return ModelState.Values
                .SelectMany(v => v.Errors)
                .Select(e => e.ErrorMessage)
                .FirstOrDefault(message => !string.IsNullOrWhiteSpace(message)) ?? "Dữ liệu không hợp lệ.";
        }

        private async Task RefreshSignInAsync(UserListItemViewModel user)
        {
            var authenticationResult = await HttpContext.AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationScheme);

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, user.Id),
                new(ClaimTypes.Name, user.FullName),
                new(ClaimTypes.Email, user.Email),
                new(ClaimTypes.Role, user.RoleName)
            };

            if (!string.IsNullOrEmpty(user.AvatarUrl))
            {
                claims.Add(new Claim("AvatarUrl", user.AvatarUrl));
            }

            var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

            var principal = new ClaimsPrincipal(identity);

            await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal, authenticationResult.Properties ?? new AuthenticationProperties());
        }
    }
}