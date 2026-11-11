using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using RentMate.Service.DTOs;
using RentMate.Service.Interfaces;
using System.Globalization;
using System.Security.Claims;

namespace RentMate.AdminSite.Infrastructure
{
    // Kiểm tra lại cookie đăng nhập mỗi phút: tài khoản bị khóa hoặc mật khẩu bị đổi/đặt lại
    // ở nơi khác thì phiên này bị đăng xuất, không phải đợi cookie hết hạn (8 tiếng).
    public static class CookieSessionValidator
    {
        private static readonly TimeSpan CheckInterval = TimeSpan.FromMinutes(1);
        private const string LastCheckedKey = "SessionLastChecked";

        public static async Task ValidateAsync(CookieValidatePrincipalContext context)
        {
            if (context.Properties.Items.TryGetValue(LastCheckedKey, out string? value) &&
                DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var lastChecked) &&
                DateTimeOffset.UtcNow - lastChecked < CheckInterval)
            {
                return;
            }

            string? userId = context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier);
            string? securityStamp = context.Principal?.FindFirstValue(SessionClaimTypes.SecurityStamp);

            var authService = context.HttpContext.RequestServices.GetRequiredService<IAuthService>();

            if (userId == null || !await authService.IsSessionValidAsync(userId, securityStamp))
            {
                context.RejectPrincipal();
                await context.HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
                return;
            }

            context.Properties.Items[LastCheckedKey] = DateTimeOffset.UtcNow.ToString("o", CultureInfo.InvariantCulture);
            context.ShouldRenew = true;
        }
    }
}
