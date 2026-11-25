using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Core.ViewModels;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    // Ngôn ngữ của app và bản dịch câu chữ
    [Area("Management")]
    [Authorize(Roles = "Admin,Manager")]
    public class LanguageController : ManagementControllerBase
    {
        private readonly ILocalizationService _localizationService;

        public LanguageController(ILocalizationService localizationService)
        {
            _localizationService = localizationService;
        }

        public async Task<IActionResult> Index()
        {
            return View(await _localizationService.GetLanguagesForManagementAsync());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(LanguageViewModel model)
        {
            if (!ModelState.IsValid)
            {
                TempData["Error"] = GetFirstModelError();
                return RedirectToAction(nameof(Index));
            }

            try
            {
                await _localizationService.CreateLanguageAsync(model, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = $"Đã thêm {model.Name}. Ngôn ngữ đang ẩn: hãy dịch rồi bật \"Hiện trên app\".";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        // Sửa bằng modal (edit-modal.js): trả JSON để modal giữ dữ liệu khi có lỗi
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(LanguageViewModel model)
        {
            // Mã ngôn ngữ không sửa được nên không kiểm tra ô này
            ModelState.Remove(nameof(LanguageViewModel.Code));

            if (!ModelState.IsValid)
                return BadRequest(new { message = GetFirstModelError() });

            try
            {
                await _localizationService.UpdateLanguageAsync(model, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Đã cập nhật ngôn ngữ.";

                return Ok();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ToggleActive(int id, bool isActive)
        {
            try
            {
                await _localizationService.SetLanguageActiveAsync(id, isActive, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = isActive ? "Ngôn ngữ đã hiện trên app." : "Đã ẩn ngôn ngữ khỏi app.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ImportDefaults()
        {
            try
            {
                var (newTexts, newTranslations) = await _localizationService.ImportDefaultsAsync(GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = newTexts == 0 && newTranslations == 0
                    ? "Câu chữ của app đã có đủ, không có gì mới."
                    : $"Đã nạp {newTexts} câu mới và {newTranslations} bản dịch tiếng Anh.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        // =========================
        // DỊCH CÂU CHỮ CỦA MỘT NGÔN NGỮ
        // =========================

        public async Task<IActionResult> Translations(int id, string? searchTerm, string? filter, int page = 1)
        {
            var model = await _localizationService.SearchTextsAsync(id, searchTerm, filter, page);

            if (model == null)
                return NotFound();

            ViewData["AutoTranslateEnabled"] = _localizationService.IsAutoTranslateEnabled;

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> SaveTranslations(int id, List<TranslationEditViewModel> items, string? searchTerm, string? filter, int page = 1)
        {
            try
            {
                int changed = await _localizationService.SaveTranslationsAsync(id, items, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = changed == 0 ? "Không có thay đổi nào." : $"Đã lưu {changed} bản dịch.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Translations), new { id, searchTerm, filter, page });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> AutoTranslate(int id)
        {
            try
            {
                int count = await _localizationService.AutoTranslateAsync(id, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = $"AI đã dịch {count} câu. Các câu này được đánh dấu \"AI dịch\", hãy xem lại rồi bấm Lưu.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Translations), new { id, filter = "machine" });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CreateText(int id, string key, string? note)
        {
            try
            {
                await _localizationService.CreateTextAsync(key, note, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Đã thêm câu cần dịch.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Translations), new { id, filter = "missing" });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteText(int id, int textId, string? searchTerm, string? filter, int page = 1)
        {
            try
            {
                await _localizationService.DeleteTextAsync(textId, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Đã xóa câu.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Translations), new { id, searchTerm, filter, page });
        }

        private string GetFirstModelError()
        {
            return ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage).FirstOrDefault(m => !string.IsNullOrWhiteSpace(m)) ?? "Dữ liệu không hợp lệ.";
        }
    }
}
