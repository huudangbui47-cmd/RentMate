using Microsoft.AspNetCore.Mvc;
using RentMate.Service.Interfaces;

namespace RentMate.Api.Controllers
{
    // Cài đặt hệ thống app cần biết (phí, giới hạn ngày thuê, số ảnh, liên hệ hỗ trợ).
    // Quản trị viên sửa ở trang Cài đặt hệ thống của AdminSite.
    [Route("api/[controller]")]
    [ApiController]
    public class SettingsController : ControllerBase
    {
        private readonly ISystemSettingService _settingService;

        public SettingsController(ISystemSettingService settingService)
        {
            _settingService = settingService;
        }

        // GET api/settings
        [HttpGet]
        public async Task<IActionResult> Get()
        {
            return Ok(await _settingService.GetPublicAsync());
        }
    }
}
