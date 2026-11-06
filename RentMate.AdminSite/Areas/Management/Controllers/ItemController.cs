using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Core.Enums;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    [Area("Management")]
    [Authorize(Roles = "Admin,Manager")]
    public class ItemController : ManagementControllerBase
    {
        private readonly IItemService _itemService;

        public ItemController(IItemService itemService)
        {
            _itemService = itemService;
        }

        public async Task<IActionResult> Index(string? searchTerm, int? categoryId, ItemStatus? status, int page = 1)
        {
            var model = await _itemService.SearchAsync(searchTerm, categoryId, status, page);

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> UpdateStatus(int id, ItemStatus status)
        {
            try
            {
                await _itemService.UpdateStatusAsync(id, status, GetCurrentUserId(), GetIpAddress());

                TempData["Success"] = "Cập nhật trạng thái đồ cho thuê thành công.";
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }
    }
}
