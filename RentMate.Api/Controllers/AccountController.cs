using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Api.Infrastructure.Storage;
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
        private readonly IFileStorageService _fileStorageService;

        public AccountController(IAuthService authService, IJwtTokenService jwtTokenService, IFileStorageService fileStorageService)
        {
            _authService = authService;
            _jwtTokenService = jwtTokenService;
            _fileStorageService = fileStorageService;
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

        // POST api/account/avatar  (multipart, field "file")
        [HttpPost("avatar")]
        [RequestSizeLimit(5 * 1024 * 1024)]
        public async Task<IActionResult> UploadAvatar(IFormFile? file)
        {
            if (file == null || file.Length == 0)
                return BadRequest("Vui lòng chọn ảnh.");

            string? imageError = _fileStorageService.ValidateImage(file);

            if (imageError != null)
                return BadRequest(imageError);

            string newAvatarUrl = await _fileStorageService.SaveAsync(file, "uploads/avatars");

            try
            {
                string? oldAvatarUrl = await _authService.UpdateAvatarAsync(GetUserId(), newAvatarUrl, GetIpAddress());

                _fileStorageService.Delete(oldAvatarUrl);

                return Ok(await _authService.GetProfileAsync(GetUserId()));
            }
            catch (ArgumentException ex)
            {
                _fileStorageService.Delete(newAvatarUrl);
                return BadRequest(ex.Message);
            }
            catch
            {
                _fileStorageService.Delete(newAvatarUrl);
                throw;
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
