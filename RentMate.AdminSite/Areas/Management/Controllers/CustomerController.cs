using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Core.ViewModels;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    [Area("Management")]
    [Authorize(Roles = "Admin,Manager")]
    public class CustomerController : ManagementControllerBase
    {
        private readonly ICustomerService _customerService;

        public CustomerController(ICustomerService customerService)
        {
            _customerService = customerService;
        }

        public async Task<IActionResult> Index(string? searchTerm, bool? isActive, int page = 1)
        {
            var model = await _customerService.SearchAsync(searchTerm, isActive, page);

            return View(model);
        }

        [HttpGet]
        public IActionResult Create()
        {
            return View(new CustomerViewModel());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(CustomerViewModel model)
        {
            // Khách mới chưa có Id; Id là string không null nên MVC tự coi là bắt buộc
            ModelState.Remove(nameof(CustomerViewModel.Id));

            if (!ModelState.IsValid)
                return View(model);

            try
            {
                string temporaryPassword = await _customerService.CreateAsync(model, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Thêm khách hàng thành công.";
                TempData["TemporaryPasswordFor"] = model.Email.Trim();
                TempData["TemporaryPassword"] = temporaryPassword;

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
        public async Task<IActionResult> Edit(CustomerViewModel model)
        {
            if (!ModelState.IsValid)
                return BadRequest(new { message = GetFirstModelError() });

            try
            {
                await _customerService.UpdateAsync(model, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Cập nhật khách hàng thành công.";

                return Ok();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        // Mật khẩu tạm chỉ hiện 1 lần trên trang danh sách để nhân viên báo cho khách
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ResetPassword(string id)
        {
            try
            {
                var customer = await _customerService.GetByIdAsync(id);

                string temporaryPassword = await _customerService.ResetPasswordAsync(id, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Đặt lại mật khẩu thành công.";
                TempData["TemporaryPasswordFor"] = customer?.Email;
                TempData["TemporaryPassword"] = temporaryPassword;
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ToggleActive(string id, bool isActive)
        {
            try
            {
                await _customerService.SetActiveAsync(id, isActive, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = isActive ? "Mở khóa khách hàng thành công." : "Khóa khách hàng thành công.";
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
