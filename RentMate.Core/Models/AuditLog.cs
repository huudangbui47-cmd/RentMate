namespace RentMate.Core.Models
{
    /// <summary>
    /// Nhật ký thao tác trên hệ thống (đăng nhập, thay đổi dữ liệu quản trị, ...).
    /// </summary>
    public class AuditLog : BaseEntity
    {
        public string Action { get; set; } = string.Empty;

        public string EntityName { get; set; } = string.Empty;

        // Khóa của đối tượng bị tác động. Dùng string vì có cả khóa int (Item)
        // lẫn khóa string (ApplicationUser).
        public string? EntityId { get; set; }

        public string? Description { get; set; }

        public string IpAddress { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Foreign Key (null khi đăng nhập thất bại với email không tồn tại)
        public string? UserId { get; set; }

        // Navigation
        public ApplicationUser? User { get; set; }
    }
}
