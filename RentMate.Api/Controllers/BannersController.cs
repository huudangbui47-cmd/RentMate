using Microsoft.AspNetCore.Mvc;
using RentMate.Service.Interfaces;

namespace RentMate.Api.Controllers
{
    // Chỉ đọc: banner được thêm/ẩn/sắp xếp bên trang quản trị (AdminSite)
    [Route("api/[controller]")]
    [ApiController]
    public class BannersController : ControllerBase
    {
        private readonly IBannerService _bannerService;

        public BannersController(IBannerService bannerService)
        {
            _bannerService = bannerService;
        }

        // Banner đang hiện, theo thứ tự quản trị sắp xếp
        [HttpGet]
        public async Task<IActionResult> GetActive()
        {
            return Ok(await _bannerService.GetActiveAsync());
        }
    }
}
