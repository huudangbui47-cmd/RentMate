namespace RentMate.Core.Models
{
    /// <summary>
    /// Một câu chữ trong app. Key là câu tiếng Việt đúng như trong code (vd. "Đơn #{0} đã hủy").
    /// </summary>
    public class TextResource : BaseEntity
    {
        public string Key { get; set; } = string.Empty;

        // Ghi chú cho người dịch (câu nằm ở đâu, {0} là gì...)
        public string? Note { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<TextTranslation> Translations { get; set; } = new List<TextTranslation>();
    }
}
