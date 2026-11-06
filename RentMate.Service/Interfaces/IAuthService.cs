using RentMate.Service.DTOs;
using RentMate.Service.DTOs.Auth;

namespace RentMate.Service.Interfaces
{
    public interface IAuthService
    {
        Task RegisterAsync(RegisterDto dto);

        Task<LoginResult> LoginAsync(string email, string password, string ipAddress);
    }
}
