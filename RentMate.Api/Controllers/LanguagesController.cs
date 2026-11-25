using Microsoft.AspNetCore.Mvc;
using RentMate.Service.Interfaces;

namespace RentMate.Api.Controllers
{
    // Ngôn ngữ và bản dịch của app; quản trị viên thêm / sửa ở trang Ngôn ngữ của AdminSite.
    // Không cần đăng nhập: màn hình đăng nhập cũng hiện theo ngôn ngữ đã chọn.
    [Route("api/[controller]")]
    [ApiController]
    public class LanguagesController : ControllerBase
    {
        private readonly ILocalizationService _localizationService;

        public LanguagesController(ILocalizationService localizationService)
        {
            _localizationService = localizationService;
        }

        // GET api/languages  (tiếng Việt là ngôn ngữ gốc, không có trong danh sách)
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            return Ok(await _localizationService.GetLanguagesAsync());
        }

        // GET api/languages/en/translations
        [HttpGet("{code}/translations")]
        public async Task<IActionResult> GetTranslations(string code)
        {
            var pack = await _localizationService.GetPackAsync(code);

            if (pack == null)
                return NotFound();

            return Ok(pack);
        }
    }
}
