using System.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.DTOs.Wallet;
using RentMate.Service.Interfaces;
using System.Security.Claims;

namespace RentMate.Api.Controllers
{
    // Nạp ví qua VNPay (sandbox)
    [Route("api/payments")]
    [ApiController]
    public class PaymentsController : ControllerBase
    {
        private readonly IVnPayService _vnPayService;

        public PaymentsController(IVnPayService vnPayService)
        {
            _vnPayService = vnPayService;
        }

        // GET api/payments/vnpay/enabled
        [HttpGet("vnpay/enabled")]
        [Authorize]
        public IActionResult Enabled() => Ok(new { enabled = _vnPayService.IsEnabled });

        // POST api/payments/vnpay  body: { amount } hoặc { rentalId }  -> link mở trang thanh toán VNPay
        [HttpPost("vnpay")]
        [Authorize]
        public async Task<IActionResult> Create(CreateVnPayPaymentDto dto)
        {
            try
            {
                var ip = HttpContext.Connection.RemoteIpAddress?.MapToIPv4().ToString() ?? "127.0.0.1";
                return Ok(await _vnPayService.CreatePaymentAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!, dto, ip));
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
            catch (Exception ex) when (ex is ArgumentException or InvalidOperationException)
            {
                return BadRequest(ex.Message);
            }
        }

        // GET api/payments/vnpay-return  (VNPay chuyển trình duyệt về đây sau khi thanh toán)
        [HttpGet("vnpay-return")]
        [AllowAnonymous]
        public async Task<IActionResult> Return()
        {
            var result = await _vnPayService.ProcessCallbackAsync(ReadQuery());

            string color = result.Success ? "#16a34a" : "#dc2626";
            string title = result.Success ? "Thanh toán thành công" : "Thanh toán chưa thành công";
            string html = $$"""
                <!doctype html><html lang="vi"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1"><title>{{title}}</title></head>
                <body style="font-family:sans-serif;display:flex;align-items:center;justify-content:center;min-height:90vh;margin:0;background:#f6f7f9">
                <div style="background:#fff;border-radius:16px;padding:28px;max-width:360px;text-align:center;box-shadow:0 4px 20px rgba(0,0,0,.08)">
                <div style="font-size:48px;color:{{color}}">{{(result.Success ? "&#10003;" : "&#10007;")}}</div>
                <h2 style="margin:8px 0">{{title}}</h2>
                <p style="color:#555">{{WebUtility.HtmlEncode(result.Message)}}</p>
                <p style="color:#888;font-size:14px">Bạn có thể quay lại ứng dụng RentMate.</p>
                </div></body></html>
                """;

            return Content(html, "text/html; charset=utf-8");
        }

        // GET api/payments/vnpay-ipn  (máy chủ VNPay gọi thẳng; chỉ chạy khi Api có địa chỉ public)
        [HttpGet("vnpay-ipn")]
        [AllowAnonymous]
        public async Task<IActionResult> Ipn()
        {
            var result = await _vnPayService.ProcessCallbackAsync(ReadQuery());
            return Ok(new { RspCode = result.RspCode, Message = result.Message });
        }

        private Dictionary<string, string> ReadQuery() =>
            Request.Query.ToDictionary(q => q.Key, q => q.Value.ToString());
    }
}
