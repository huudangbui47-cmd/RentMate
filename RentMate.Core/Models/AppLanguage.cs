namespace RentMate.Core.Models
{
    /// <summary>
    /// Ngôn ngữ của app. Tiếng Việt là ngôn ngữ gốc (câu tiếng Việt chính là khóa) nên không có dòng ở đây.
    /// </summary>
    public class AppLanguage : BaseEntity
    {
        // Mã ISO 639-1: en, zh, ja, fr...
        public string Code { get; set; } = string.Empty;

        // Tên bằng chính ngôn ngữ đó: English, 中文, 日本語...
        public string Name { get; set; } = string.Empty;

        public string? Flag { get; set; }

        public bool IsActive { get; set; } = true;

        public int SortOrder { get; set; }

        // Đổi mỗi khi bản dịch của ngôn ngữ này thay đổi, app dựa vào đây để biết cần tải lại
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<TextTranslation> Translations { get; set; } = new List<TextTranslation>();
    }
}
