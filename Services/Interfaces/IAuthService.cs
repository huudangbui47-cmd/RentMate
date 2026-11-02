using RentMate.Api.DTOs.Auth;

namespace RentMate.Api.Services.Interfaces
{
    public interface IAuthService
    {
        Task RegisterAsync(RegisterDto dto);

        Task<AuthResponseDto> LoginAsync(LoginDto dto);
    }
}