namespace RentMate.Core.ViewModels
{
    // Một ảnh trên trang "Banner trang chủ"
    public class BannerViewModel
    {
        public int Id { get; set; }

        public string ImageUrl { get; set; } = string.Empty;

        public string? Title { get; set; }

        public int SortOrder { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }

        public string StatusText => IsActive ? "Đang hiện" : "Đang ẩn";
    }
}
