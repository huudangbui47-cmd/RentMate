using RentMate.Service.DTOs;
using RentMate.Service.DTOs.Auth;

namespace RentMate.Service.Interfaces
{
    public interface IAuthService
    {
        Task RegisterAsync(RegisterDto dto);

        // allowedRoles = null: mọi role đều được đăng nhập (API cho khách).
        // Trang quản trị truyền { "Admin", "Manager" }.
        Task<LoginResult> LoginAsync(string email, string password, string ipAddress, string[]? allowedRoles = null);
    }
}
