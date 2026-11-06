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
                return Ok(new { message = "Registered successfully. Please login." });
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
                return Unauthorized("Too many failed attempts. Please try again later.");
            }

            if (result.Status == LoginStatus.Inactive)
            {
                return Unauthorized("This account is inactive.");
            }

            return Unauthorized("Invalid email or password.");
        }
    }
}
