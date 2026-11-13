using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Api.Security;
using RentMate.Service.DTOs.Auth;
using RentMate.Service.Interfaces;
using System.Security.Claims;

namespace RentMate.Api.Controllers
{
    // Tài khoản của người đang đăng nhập (trang "Tài khoản" trên app)
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class AccountController : ControllerBase
    {
        private readonly IAuthService _authService;
        private readonly IJwtTokenService _jwtTokenService;

        public AccountController(IAuthService authService, IJwtTokenService jwtTokenService)
        {
            _authService = authService;
            _jwtTokenService = jwtTokenService;
        }

        // GET api/account/me
        [HttpGet("me")]
        public async Task<IActionResult> GetProfile()
        {
            var profile = await _authService.GetProfileAsync(GetUserId());

            return profile == null ? NotFound() : Ok(profile);
        }

        // PUT api/account/me
        [HttpPut("me")]
        public async Task<IActionResult> UpdateProfile(UpdateProfileDto dto)
        {
            try
            {
                await _authService.UpdateProfileAsync(GetUserId(), dto, GetIpAddress());

                return Ok(await _authService.GetProfileAsync(GetUserId()));
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // PUT api/account/password
        // Đổi mật khẩu làm token cũ hết hiệu lực (máy khác bị đăng xuất), nên trả token mới cho máy đang dùng
        [HttpPut("password")]
        [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status200OK)]
        public async Task<IActionResult> ChangePassword(ChangePasswordDto dto)
        {
            try
            {
                var user = await _authService.ChangePasswordAsync(GetUserId(), dto, GetIpAddress());

                return Ok(_jwtTokenService.GenerateToken(user));
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

        private string GetIpAddress() => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Không xác định";
    }
}
