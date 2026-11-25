namespace RentMate.Core.ViewModels
{
    // Ngôn ngữ có sẵn để admin chọn khi thêm, không phải tự tra mã ISO hay cờ
    public class LanguagePresetOption
    {
        public string Code { get; set; } = string.Empty;

        // Tên bằng chính ngôn ngữ đó, hiện trên app
        public string NativeName { get; set; } = string.Empty;

        // Tên tiếng Việt, hiện trên trang quản trị
        public string VietnameseName { get; set; } = string.Empty;

        public string Flag { get; set; } = string.Empty;

        public static readonly List<LanguagePresetOption> All = new()
        {
            new() { Code = "en", NativeName = "English", VietnameseName = "Tiếng Anh", Flag = "🇬🇧" },
            new() { Code = "zh", NativeName = "中文", VietnameseName = "Tiếng Trung", Flag = "🇨🇳" },
            new() { Code = "ja", NativeName = "日本語", VietnameseName = "Tiếng Nhật", Flag = "🇯🇵" },
            new() { Code = "ko", NativeName = "한국어", VietnameseName = "Tiếng Hàn", Flag = "🇰🇷" },
            new() { Code = "fr", NativeName = "Français", VietnameseName = "Tiếng Pháp", Flag = "🇫🇷" },
            new() { Code = "de", NativeName = "Deutsch", VietnameseName = "Tiếng Đức", Flag = "🇩🇪" },
            new() { Code = "es", NativeName = "Español", VietnameseName = "Tiếng Tây Ban Nha", Flag = "🇪🇸" },
            new() { Code = "ru", NativeName = "Русский", VietnameseName = "Tiếng Nga", Flag = "🇷🇺" },
            new() { Code = "th", NativeName = "ไทย", VietnameseName = "Tiếng Thái", Flag = "🇹🇭" },
            new() { Code = "id", NativeName = "Bahasa Indonesia", VietnameseName = "Tiếng Indonesia", Flag = "🇮🇩" },
            new() { Code = "km", NativeName = "ខ្មែរ", VietnameseName = "Tiếng Khmer", Flag = "🇰🇭" },
            new() { Code = "lo", NativeName = "ລາວ", VietnameseName = "Tiếng Lào", Flag = "🇱🇦" },
        };

        public static LanguagePresetOption? Find(string? code) => All.FirstOrDefault(o => o.Code == code);
    }
}
