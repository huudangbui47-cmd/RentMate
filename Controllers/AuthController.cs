using Microsoft.AspNetCore.Mvc;
using RentMate.Api.DTOs.Auth;
using RentMate.Api.Services.Interfaces;

namespace RentMate.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;

        public AuthController(IAuthService authService)
        {
            _authService = authService;
        }

        // POST: api/auth/register
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
        [HttpPost("login")]
        public async Task<IActionResult> Login(
            LoginDto dto)
        {
            try
            {
                var result =
                    await _authService.LoginAsync(dto);

                return Ok(result);
            }
            catch (UnauthorizedAccessException ex)
            {
                return Unauthorized(ex.Message);
            }
        }
    }
}