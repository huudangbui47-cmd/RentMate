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

        // Dùng để đăng xuất phiên cũ khi tài khoản bị khóa hoặc đổi/đặt lại mật khẩu
        Task<bool> IsSessionValidAsync(string userId, string? securityStamp);

        Task<string?> GetSecurityStampAsync(string userId);

        // Tài khoản khách trên app
        Task<ProfileDto?> GetProfileAsync(string userId);

        Task UpdateProfileAsync(string userId, UpdateProfileDto dto, string ipAddress);

        // Trả về đường dẫn ảnh đại diện cũ để xóa file
        Task<string?> UpdateAvatarAsync(string userId, string avatarUrl, string ipAddress);

        Task<AuthenticatedUser> ChangePasswordAsync(string userId, ChangePasswordDto dto, string ipAddress);

        Task RequestPasswordResetCodeAsync(string email, string ipAddress);

        Task ResetPasswordWithCodeAsync(ResetPasswordWithCodeDto dto, string ipAddress);
    }
}
