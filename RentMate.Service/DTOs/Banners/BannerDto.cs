namespace RentMate.Service.DTOs.Banners
{
    // Banner đang bật, app hiển thị theo đúng thứ tự trả về
    public class BannerDto
    {
        public int BannerId { get; set; }

        // Đường dẫn tương đối trên Api, app ghép với địa chỉ Api
        public string ImageUrl { get; set; } = string.Empty;
    }
}
