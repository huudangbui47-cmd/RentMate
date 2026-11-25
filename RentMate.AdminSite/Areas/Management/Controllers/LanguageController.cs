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
            ViewData["AutoTranslateEnabled"] = _localizationService.IsAutoTranslateEnabled;

            return View(await _localizationService.GetLanguagesForManagementAsync());
        }

        // Chọn ngôn ngữ trong danh sách có sẵn (tên, cờ điền sẵn); AI dịch toàn bộ app rồi hiện luôn trên app.
        // Không có dịch tự động thì không thêm được ngôn ngữ (dịch tay hàng trăm câu không thực tế): app dùng Tiếng Việt và English.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(LanguageViewModel model)
        {
            if (!_localizationService.IsAutoTranslateEnabled)
            {
                TempData["Error"] = "Chưa bật dịch tự động (khóa AI) nên chưa thêm được ngôn ngữ mới. App đang dùng Tiếng Việt và English.";
                return RedirectToAction(nameof(Index));
            }

            // Chọn từ danh sách có sẵn thì không cần nhập tên
            if (LanguagePresetOption.Find(model.Code) != null)
                ModelState.Remove(nameof(LanguageViewModel.Name));

            if (!ModelState.IsValid)
            {
                TempData["Error"] = GetFirstModelError();
                return RedirectToAction(nameof(Index));
            }

            int languageId;

            try
            {
                languageId = await _localizationService.CreateLanguageAsync(model, GetCurrentUserId(), GetIpAddress());
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
                return RedirectToAction(nameof(Index));
            }

            try
            {
                var (translated, missing) = await _localizationService.AutoTranslateAsync(languageId, true, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = missing == 0
                    ? $"Đã thêm ngôn ngữ, AI dịch xong {translated} câu và ngôn ngữ đã hiện trên app. Bạn có thể xem lại bản dịch bất cứ lúc nào."
                    : $"Đã thêm ngôn ngữ, AI dịch được {translated} câu, còn {missing} câu chưa dịch. Bấm \"Dịch phần còn thiếu bằng AI\" rồi bật \"Hiện trên app\".";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = "Đã thêm ngôn ngữ nhưng chưa dịch được: " + ex.Message;
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
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                await _localizationService.DeleteLanguageAsync(id, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Đã xóa ngôn ngữ.";
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
                var (count, missing) = await _localizationService.AutoTranslateAsync(id, false, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = $"AI đã dịch {count} câu" + (missing > 0 ? $", còn {missing} câu chưa dịch được" : "") +
                    ". Các câu này được đánh dấu \"AI dịch\", có thể xem lại và sửa.";
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
