using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Core.ViewModels;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    // Admin quản lý tài khoản Quản lý (Manager)
    [Area("Management")]
    [Authorize(Roles = "Admin")]
    public class UserController : ManagementControllerBase
    {
        private readonly IAccountService _accountService;

        public UserController(IAccountService accountService)
        {
            _accountService = accountService;
        }

        public async Task<IActionResult> Index(string? searchTerm, bool? isActive, int page = 1)
        {
            var model = await _accountService.SearchAsync(searchTerm, isActive, page);

            return View(model);
        }

        [HttpGet]
        public IActionResult Create()
        {
            return View(new UserCreateViewModel());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(UserCreateViewModel model)
        {
            if (!ModelState.IsValid)
                return View(model);

            try
            {
                await _accountService.CreateAsync(model, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Tạo tài khoản quản lý thành công.";

                return RedirectToAction(nameof(Index));
            }
            catch (InvalidOperationException ex)
            {
                ModelState.AddModelError(string.Empty, ex.Message);

                return View(model);
            }
        }

        // Sửa bằng modal trên trang danh sách: trả JSON để modal giữ nguyên dữ liệu khi có lỗi
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(UserEditViewModel model)
        {
            if (!ModelState.IsValid)
                return BadRequest(new { message = GetFirstModelError() });

            try
            {
                await _accountService.UpdateUserAsync(model, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Cập nhật tài khoản thành công.";

                return Ok();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ToggleActive(string id, bool isActive)
        {
            try
            {
                await _accountService.SetActiveAsync(id, isActive, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = isActive ? "Mở khóa tài khoản thành công." : "Khóa tài khoản thành công.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(string id)
        {
            try
            {
                await _accountService.DeleteAsync(id, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Xóa tài khoản thành công.";
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
