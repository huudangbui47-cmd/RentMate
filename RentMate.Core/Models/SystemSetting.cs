namespace RentMate.Core.Models
{
    /// <summary>
    /// Một cài đặt hệ thống quản trị viên chỉnh được trên trang quản trị (phí, giới hạn, số ngày...).
    /// Chỉ lưu những cài đặt đã được sửa; chưa có dòng thì dùng giá trị mặc định khai báo trong SystemSettingService.
    /// </summary>
    public class SystemSetting : BaseEntity
    {
        public string Key { get; set; } = string.Empty;

        public string Value { get; set; } = string.Empty;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        public string? UpdatedByUserId { get; set; }
    }
}
