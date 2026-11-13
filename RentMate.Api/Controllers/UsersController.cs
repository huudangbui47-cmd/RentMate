using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.Interfaces;

namespace RentMate.Api.Controllers
{
    // Hồ sơ công khai của người dùng khác (trang hồ sơ chủ đồ trên app)
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class UsersController : ControllerBase
    {
        private readonly IAuthService _authService;

        public UsersController(IAuthService authService)
        {
            _authService = authService;
        }

        // GET api/users/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetPublicProfile(string id)
        {
            var profile = await _authService.GetPublicProfileAsync(id);

            return profile == null ? NotFound() : Ok(profile);
        }
    }
}
