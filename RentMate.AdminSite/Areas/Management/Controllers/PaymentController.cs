using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Core.Enums;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    [Area("Management")]
    [Authorize(Roles = "Admin,Manager")]
    public class PaymentController : ManagementControllerBase
    {
        private readonly IPaymentService _paymentService;

        public PaymentController(IPaymentService paymentService)
        {
            _paymentService = paymentService;
        }

        public async Task<IActionResult> Index(PaymentStatus? status, PaymentType? paymentType, DateTime? fromDate, DateTime? toDate, int page = 1)
        {
            var model = await _paymentService.SearchAsync(status, paymentType, fromDate, toDate, page);

            return View(model);
        }
    }
}
