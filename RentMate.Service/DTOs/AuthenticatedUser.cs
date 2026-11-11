namespace RentMate.Service.DTOs
{
    public class AuthenticatedUser
    {
        public string Id { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string RoleName { get; set; } = string.Empty;
        public string? AvatarUrl { get; set; }

        // Lưu vào cookie/JWT để phát hiện mật khẩu đã bị đổi ở nơi khác
        public string SecurityStamp { get; set; } = string.Empty;
    }
}
