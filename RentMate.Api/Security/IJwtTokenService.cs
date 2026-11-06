using RentMate.Service.DTOs;
using RentMate.Service.DTOs.Auth;

namespace RentMate.Api.Security;

public interface IJwtTokenService
{
    AuthResponseDto GenerateToken(AuthenticatedUser user);
}
