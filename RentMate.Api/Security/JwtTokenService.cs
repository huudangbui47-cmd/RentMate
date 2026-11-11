using Microsoft.IdentityModel.Tokens;
using RentMate.Service.DTOs;
using RentMate.Service.DTOs.Auth;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace RentMate.Api.Security
{
    public class JwtTokenService : IJwtTokenService
    {
        private readonly IConfiguration _configuration;

        public JwtTokenService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public AuthResponseDto GenerateToken(AuthenticatedUser user)
        {
            string key = _configuration["Jwt:Key"] ?? throw new InvalidOperationException("Thiếu cấu hình Jwt:Key.");

            string issuer = _configuration["Jwt:Issuer"] ?? throw new InvalidOperationException("Thiếu cấu hình Jwt:Issuer.");

            string audience = _configuration["Jwt:Audience"] ?? throw new InvalidOperationException("Thiếu cấu hình Jwt:Audience.");

            int expireMinutes = int.TryParse(_configuration["Jwt:ExpireMinutes"], out int minutes) ? minutes : 1440;

            DateTime expiresAt = DateTime.UtcNow.AddMinutes(expireMinutes);

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, user.Id),
                new(ClaimTypes.Name, user.FullName),
                new(ClaimTypes.Email, user.Email),
                new(ClaimTypes.Role, user.RoleName),
                new(SessionClaimTypes.SecurityStamp, user.SecurityStamp),
                new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));

            var credentials = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                issuer: issuer,
                audience: audience,
                claims: claims,
                expires: expiresAt,
                signingCredentials: credentials);

            return new AuthResponseDto
            {
                UserId = user.Id,
                FullName = user.FullName,
                Email = user.Email,
                Token = new JwtSecurityTokenHandler().WriteToken(token),
                ExpiresAt = expiresAt
            };
        }
    }
}
