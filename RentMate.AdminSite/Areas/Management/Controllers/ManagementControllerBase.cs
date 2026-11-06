using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    public abstract class ManagementControllerBase : Controller
    {
        protected string GetCurrentUserId()
        {
            string? userIdValue = User.FindFirstValue(ClaimTypes.NameIdentifier);

            if (string.IsNullOrEmpty(userIdValue))
                throw new InvalidOperationException(
                    "Không xác định được người dùng hiện tại.");

            return userIdValue;
        }

        protected string GetIpAddress()
        {
            return HttpContext.Connection.RemoteIpAddress?.ToString()
                ?? "Không xác định";
        }
    }
}
