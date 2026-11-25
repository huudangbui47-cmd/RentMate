using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.AdminSite.Infrastructure.Storage;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    // Ảnh chạy ở đầu Trang chủ của app
    [Area("Management")]
    [Authorize(Roles = "Admin,Manager")]
    public class BannerController : ManagementControllerBase
    {
        private const long MaxBannerSize = 5 * 1024 * 1024;

        private readonly IBannerService _bannerService;
        private readonly IFileStorageService _fileStorageService;

        public BannerController(IBannerService bannerService, IFileStorageService fileStorageService)
        {
            _bannerService = bannerService;
            _fileStorageService = fileStorageService;
        }

        public async Task<IActionResult> Index()
        {
            return View(await _bannerService.GetAllForManagementAsync());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(IFormFile? image, string? title)
        {
            if (image == null || image.Length == 0)
            {
                TempData["Error"] = "Vui lòng chọn ảnh banner.";
                return RedirectToAction(nameof(Index));
            }

            string? imageError = _fileStorageService.ValidateImage(image, MaxBannerSize);

            if (imageError != null)
            {
                TempData["Error"] = imageError;
                return RedirectToAction(nameof(Index));
            }

            // Lưu vào thư mục dùng chung để Api phục vụ được cho app
            string imageUrl = await _fileStorageService.SaveSharedAsync(image, "banners");

            try
            {
                await _bannerService.CreateAsync(imageUrl, title, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Thêm banner thành công.";
            }
            catch (InvalidOperationException ex)
            {
                _fileStorageService.Delete(imageUrl);
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ToggleActive(int id, bool isActive)
        {
            try
            {
                await _bannerService.SetActiveAsync(id, isActive, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = isActive ? "Đã hiện banner trên app." : "Đã ẩn banner khỏi app.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Move(int id, bool up)
        {
            try
            {
                await _bannerService.MoveAsync(id, up, GetCurrentUserId(), GetIpAddress());
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                string imageUrl = await _bannerService.DeleteAsync(id, GetCurrentUserId(), GetIpAddress());

                // Xóa file sau khi đã xóa dòng trong database
                _fileStorageService.Delete(imageUrl);

                TempData["Success"] = "Xóa banner thành công.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }
    }
}
