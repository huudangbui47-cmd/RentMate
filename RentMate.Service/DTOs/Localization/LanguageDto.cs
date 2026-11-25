namespace RentMate.Service.DTOs.Localization
{
    public class LanguageDto
    {
        public string Code { get; set; } = string.Empty;

        public string Name { get; set; } = string.Empty;

        public string? Flag { get; set; }

        // Đổi khi bản dịch thay đổi; app so với bản đã lưu để biết có cần tải lại không
        public long Version { get; set; }
    }
}
