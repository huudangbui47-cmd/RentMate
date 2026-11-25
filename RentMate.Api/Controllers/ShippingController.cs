using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.Interfaces;

namespace RentMate.Api.Controllers
{
    // Danh mục tỉnh / quận / phường của GHN cho ô địa chỉ nhận hàng
    [Route("api/shipping")]
    [ApiController]
    [Authorize]
    public class ShippingController : ControllerBase
    {
        private readonly IShippingService _shippingService;

        public ShippingController(IShippingService shippingService)
        {
            _shippingService = shippingService;
        }

        // GET api/shipping/enabled  (app ẩn lựa chọn giao hàng khi chưa cấu hình GHN)
        [HttpGet("enabled")]
        public IActionResult Enabled() => Ok(new { enabled = _shippingService.IsEnabled });

        // GET api/shipping/provinces
        [HttpGet("provinces")]
        public Task<IActionResult> Provinces() => Run(() => _shippingService.GetProvincesAsync());

        // GET api/shipping/districts?provinceId=202
        [HttpGet("districts")]
        public Task<IActionResult> Districts(int provinceId) => Run(() => _shippingService.GetDistrictsAsync(provinceId));

        // GET api/shipping/wards?districtId=1442
        [HttpGet("wards")]
        public Task<IActionResult> Wards(int districtId) => Run(() => _shippingService.GetWardsAsync(districtId));

        private static async Task<IActionResult> Run<T>(Func<Task<T>> action)
        {
            try
            {
                return new OkObjectResult(await action());
            }
            catch (InvalidOperationException ex)
            {
                return new BadRequestObjectResult(ex.Message);
            }
        }
    }
}
