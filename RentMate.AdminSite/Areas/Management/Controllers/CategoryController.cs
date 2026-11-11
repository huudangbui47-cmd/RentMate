using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Core.ViewModels;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    [Area("Management")]
    [Authorize(Roles = "Admin,Manager")]
    public class CategoryController : ManagementControllerBase
    {
        private readonly ICategoryService _categoryService;

        public CategoryController(ICategoryService categoryService)
        {
            _categoryService = categoryService;
        }

        public async Task<IActionResult> Index()
        {
            var categories = await _categoryService.GetAllForManagementAsync();

            // Danh sách danh mục cha cho ô "Thuộc danh mục" trong modal sửa
            ViewData["ParentOptions"] = await _categoryService.GetParentOptionsAsync();

            return View(categories);
        }

        // parentId có giá trị khi bấm "Thêm danh mục con" ở một danh mục cha
        [HttpGet]
        public async Task<IActionResult> Create(int? parentId)
        {
            ViewData["ParentOptions"] = await _categoryService.GetParentOptionsAsync();

            return View(new CategoryViewModel { ParentCategoryId = parentId });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(CategoryViewModel model)
        {
            ViewData["ParentOptions"] = await _categoryService.GetParentOptionsAsync();

            if (!ModelState.IsValid)
                return View(model);

            try
            {
                await _categoryService.CreateAsync(model, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Thêm danh mục thành công.";

                return RedirectToAction(nameof(Index));
            }
            catch (InvalidOperationException ex)
            {
                ModelState.AddModelError(string.Empty, ex.Message);

                return View(model);
            }
        }

        // Sửa bằng modal trên trang danh sách: trả JSON để modal giữ nguyên dữ liệu khi có lỗi.
        // Trạng thái hoạt động đổi bằng nút ổ khóa, không sửa ở đây.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(CategoryViewModel model)
        {
            if (!ModelState.IsValid)
                return BadRequest(new { message = GetFirstModelError() });

            try
            {
                await _categoryService.UpdateAsync(model, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Cập nhật danh mục thành công.";

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
                await _categoryService.SetActiveAsync(id, isActive, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = isActive ? "Mở lại hoạt động danh mục thành công." : "Ngừng hoạt động danh mục thành công.";
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
                await _categoryService.DeleteAsync(id, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Xóa danh mục thành công.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        private string GetFirstModelError()
        {
            return ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage).FirstOrDefault(message => !string.IsNullOrWhiteSpace(message)) ?? "Dữ liệu không hợp lệ.";
        }
    }
}
