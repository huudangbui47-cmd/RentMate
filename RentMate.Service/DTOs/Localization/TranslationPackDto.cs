namespace RentMate.Service.DTOs.Localization
{
    // Toàn bộ bản dịch của một ngôn ngữ: khóa là câu tiếng Việt, giá trị là bản dịch
    public class TranslationPackDto
    {
        public string Code { get; set; } = string.Empty;

        public long Version { get; set; }

        public Dictionary<string, string> Texts { get; set; } = new();
    }
}
