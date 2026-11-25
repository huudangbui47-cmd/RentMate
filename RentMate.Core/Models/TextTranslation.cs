namespace RentMate.Core.Models
{
    /// <summary>
    /// Bản dịch một câu sang một ngôn ngữ.
    /// </summary>
    public class TextTranslation : BaseEntity
    {
        public int TextResourceId { get; set; }

        public TextResource TextResource { get; set; } = null!;

        public int LanguageId { get; set; }

        public AppLanguage Language { get; set; } = null!;

        public string Value { get; set; } = string.Empty;

        // true: AI dịch tự động, chưa có người xem lại
        public bool IsMachineTranslated { get; set; }

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
