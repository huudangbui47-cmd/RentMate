using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using RentMate.Api.DTOs.Auth;
using RentMate.Api.Models;
using RentMate.Api.Services.Interfaces;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace RentMate.Api.Services
{
    public class AuthService : IAuthService
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IConfiguration _configuration;

        public AuthService(
            UserManager<ApplicationUser> userManager,
            IConfiguration configuration)
        {
            _userManager = userManager;
            _configuration = configuration;
        }

        // =========================
        // REGISTER
        // =========================
        public async Task<AuthResponseDto> RegisterAsync(RegisterDto dto)
        {
            var existingUser =
                await _userManager.FindByEmailAsync(dto.Email);

            if (existingUser != null)
            {
                throw new ArgumentException(
                    "Email is already registered.");
            }

            var user = new ApplicationUser
            {
                FullName = dto.FullName.Trim(),
                Email = dto.Email.Trim(),
                UserName = dto.Email.Trim(),
                PhoneNumber = dto.PhoneNumber.Trim(),
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            var result =
                await _userManager.CreateAsync(
                    user,
                    dto.Password);

            if (!result.Succeeded)
            {
                var errors = string.Join(
                    "; ",
                    result.Errors.Select(e => e.Description));

                throw new ArgumentException(errors);
            }

            return GenerateAuthResponse(user);
        }

        // =========================
        // LOGIN
        // =========================
        public async Task<AuthResponseDto> LoginAsync(LoginDto dto)
        {
            var user =
                await _userManager.FindByEmailAsync(dto.Email);

            if (user == null)
            {
                throw new UnauthorizedAccessException(
                    "Invalid email or password.");
            }

            if (!user.IsActive)
            {
                throw new UnauthorizedAccessException(
                    "This account is inactive.");
            }

            var passwordValid =
                await _userManager.CheckPasswordAsync(
                    user,
                    dto.Password);

            if (!passwordValid)
            {
                throw new UnauthorizedAccessException(
                    "Invalid email or password.");
            }

            return GenerateAuthResponse(user);
        }

        // =========================
        // JWT
        // =========================
        private AuthResponseDto GenerateAuthResponse(
            ApplicationUser user)
        {
            var jwtKey =
                _configuration["Jwt:Key"]
                ?? throw new InvalidOperationException(
                    "JWT Key is missing.");

            var expireMinutes =
                int.Parse(
                    _configuration["Jwt:ExpireMinutes"]
                    ?? "1440");

            var expiresAt =
                DateTime.UtcNow.AddMinutes(expireMinutes);

            var claims = new List<Claim>
            {
                new Claim(
                    ClaimTypes.NameIdentifier,
                    user.Id),

                new Claim(
                    ClaimTypes.Name,
                    user.FullName),

                new Claim(
                    ClaimTypes.Email,
                    user.Email ?? string.Empty),

                new Claim(
                    JwtRegisteredClaimNames.Jti,
                    Guid.NewGuid().ToString())
            };

            var key =
                new SymmetricSecurityKey(
                    Encoding.UTF8.GetBytes(jwtKey));

            var credentials =
                new SigningCredentials(
                    key,
                    SecurityAlgorithms.HmacSha256);

            var token =
                new JwtSecurityToken(
                    issuer:
                        _configuration["Jwt:Issuer"],

                    audience:
                        _configuration["Jwt:Audience"],

                    claims:
                        claims,

                    expires:
                        expiresAt,

                    signingCredentials:
                        credentials);

            return new AuthResponseDto
            {
                UserId = user.Id,
                FullName = user.FullName,
                Email = user.Email ?? string.Empty,

                Token =
                    new JwtSecurityTokenHandler()
                        .WriteToken(token),

                ExpiresAt = expiresAt
            };
        }
    }
}