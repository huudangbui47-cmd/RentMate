namespace RentMate.Service.DTOs
{
    // Mục "Ghn" trong appsettings. Token và ShopId lấy ở trang GHN dành cho nhà phát triển.
    // Để trống Token thì app chỉ có cách nhận đồ trực tiếp.
    public class GhnSettings
    {
        public string? Token { get; set; }

        public int ShopId { get; set; }

        // Môi trường thử của GHN; chạy thật đổi thành https://online-gateway.ghn.vn/shiip/public-api
        public string BaseUrl { get; set; } = "https://dev-online-gateway.ghn.vn/shiip/public-api";
    }
}
