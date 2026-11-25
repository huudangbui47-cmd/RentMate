namespace RentMate.Core.Models
{
    // Ảnh chạy ở đầu Trang chủ của app, quản trị viên tải lên trên AdminSite
    public class Banner : BaseEntity
    {
        // Đường dẫn tương đối, vd. /shared/banners/abc.jpg (thư mục ảnh dùng chung của AdminSite và Api)
        public string ImageUrl { get; set; } = string.Empty;

        // Ghi chú cho quản trị (không hiện trên app)
        public string? Title { get; set; }

        // Số nhỏ hiện trước
        public int SortOrder { get; set; }

        public bool IsActive { get; set; } = true;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
