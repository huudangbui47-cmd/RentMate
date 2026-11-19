namespace RentMate.Service.DTOs
{
    // Mục "Ai" trong appsettings của Api. Không có ApiKey thì biên bản vẫn lập được, chỉ không có phần AI đánh giá.
    public class AiSettings
    {
        public string? ApiKey { get; set; }

        public string Model { get; set; } = "claude-opus-5-5";
    }
}
