using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Core.Enums;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    // Liên quan tiền thật nên chỉ Admin xử lý
    [Area("Management")]
    [Authorize(Roles = "Admin")]
    public class WalletController : ManagementControllerBase
    {
        private readonly IWalletService _walletService;

        public WalletController(IWalletService walletService)
        {
            _walletService = walletService;
        }

        // Mặc định mở danh sách đang chờ xử lý; chọn "Tất cả trạng thái" thì status = null
        public async Task<IActionResult> Index(WalletTransactionType? type, WalletTransactionStatus? status, string? searchTerm, int page = 1, bool all = false)
        {
            if (!all && status == null)
                status = WalletTransactionStatus.Pending;

            var model = await _walletService.SearchRequestsAsync(type, status, searchTerm, page);

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ApproveDeposit(int id)
        {
            return await RunAsync(
                () => _walletService.ApproveDepositAsync(id, GetCurrentUserId(), GetIpAddress()),
                "Đã duyệt nạp tiền. Số dư của khách đã được cộng.");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CompleteWithdraw(int id)
        {
            return await RunAsync(
                () => _walletService.CompleteWithdrawAsync(id, GetCurrentUserId(), GetIpAddress()),
                "Đã xác nhận chuyển tiền. Số dư của khách đã được trừ.");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Reject(int id, string? reason)
        {
            return await RunAsync(
                () => _walletService.RejectRequestAsync(id, GetCurrentUserId(), reason, GetIpAddress()),
                "Đã từ chối yêu cầu. Khách sẽ thấy lý do trong app.");
        }

        private async Task<IActionResult> RunAsync(Func<Task> action, string successMessage)
        {
            try
            {
                await action();

                TempData["Success"] = successMessage;
            }
            catch (InvalidOperationException ex)
            {
                TempData["Error"] = ex.Message;
            }
            catch (ArgumentException ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }
    }
}
