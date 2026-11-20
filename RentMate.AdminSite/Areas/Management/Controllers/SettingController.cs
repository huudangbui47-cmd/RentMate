using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    // Cài đặt hệ thống (phí, giới hạn, tài khoản nhận tiền...): liên quan tiền nên chỉ Admin
    [Area("Management")]
    [Authorize(Roles = "Admin")]
    public class SettingController : ManagementControllerBase
    {
        // Ô nhập trên trang có tên "setting.<Key>"
        private const string FieldPrefix = "setting.";

        private readonly ISystemSettingService _settingService;

        public SettingController(ISystemSettingService settingService)
        {
            _settingService = settingService;
        }

        public async Task<IActionResult> Index()
        {
            return View(await _settingService.GetAllForManagementAsync());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Save(IFormCollection form)
        {
            var values = form.Keys
                .Where(k => k.StartsWith(FieldPrefix, StringComparison.Ordinal))
                .ToDictionary(k => k[FieldPrefix.Length..], k => (string?)form[k].ToString());

            try
            {
                await _settingService.UpdateAsync(values, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Đã lưu cài đặt. App và trang quản trị áp dụng giá trị mới trong vòng 30 giây.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }
    }
}
