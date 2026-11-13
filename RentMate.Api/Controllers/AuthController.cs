using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Api.Security;
using RentMate.Core.Enums;
using RentMate.Service.DTOs.Auth;
using RentMate.Service.Interfaces;

namespace RentMate.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;
        private readonly IJwtTokenService _jwtTokenService;

        public AuthController(IAuthService authService, IJwtTokenService jwtTokenService)
        {
            _authService = authService;
            _jwtTokenService = jwtTokenService;
        }

        // POST: api/auth/register
        [AllowAnonymous]
        [HttpPost("register")]
        public async Task<IActionResult> Register(
            RegisterDto dto)
        {
            try
            {
                await _authService.RegisterAsync(dto);

                // Token is only issued on login
                return Ok(new { message = "Đăng ký thành công. Vui lòng đăng nhập." });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // POST: api/auth/login
        [AllowAnonymous]
        [HttpPost("login")]
        [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> Login(
            LoginDto dto)
        {
            string ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Không xác định";

            var result = await _authService.LoginAsync(dto.Email, dto.Password, ipAddress);

            if (result.Status == LoginStatus.Success && result.User != null)
            {
                var token = _jwtTokenService.GenerateToken(result.User);

                return Ok(token);
            }

            if (result.Status == LoginStatus.TemporarilyLocked)
            {
                return Unauthorized("Bạn nhập sai quá nhiều lần. Vui lòng thử lại sau 5 phút.");
            }

            if (result.Status == LoginStatus.Inactive)
            {
                return Unauthorized("Tài khoản đã bị khóa. Vui lòng liên hệ RentMate.");
            }

            return Unauthorized("Email hoặc mật khẩu không đúng.");
        }

        // POST: api/auth/forgot-password  -> gửi mã 6 số vào email
        [AllowAnonymous]
        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword(ForgotPasswordDto dto)
        {
            try
            {
                await _authService.RequestPasswordResetCodeAsync(dto.Email, GetIpAddress());
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
            catch (InvalidOperationException ex)
            {
                // Gửi email thất bại (chưa cấu hình Smtp đúng...)
                return BadRequest(ex.Message);
            }

            // Luôn báo cùng một câu dù email có tồn tại hay không
            return Ok(new { message = "Nếu email đã đăng ký, mã xác nhận đã được gửi. Vui lòng kiểm tra hộp thư (kể cả mục Spam)." });
        }

        // POST: api/auth/reset-password  -> nhập mã + mật khẩu mới
        [AllowAnonymous]
        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword(ResetPasswordWithCodeDto dto)
        {
            try
            {
                await _authService.ResetPasswordWithCodeAsync(dto, GetIpAddress());

                return Ok(new { message = "Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới." });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        private string GetIpAddress() => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Không xác định";
    }
}
