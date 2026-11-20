using RentMate.Core.Enums;

namespace RentMate.Core.Models
{
    public class ConditionReport : BaseEntity
    {
        public ConditionReportType ReportType { get; set; }

        public ItemCondition Condition { get; set; }

        public string? Description { get; set; }

        public DateTime CreatedAt { get; set; }
            = DateTime.UtcNow;

        // AI xem ảnh và đánh giá (chỉ là gợi ý). Null khi chưa bật AI hoặc AI lỗi.
        public string? AiSummary { get; set; }

        // Mỗi dòng một hư hỏng AI thấy
        public string? AiDamages { get; set; }

        public ItemCondition? AiSuggestedCondition { get; set; }

        public bool? AiNewDamageFound { get; set; }

        // AI thấy đồ trong ảnh khác món đã đăng / đã giao
        public bool? AiSameItem { get; set; }

        public decimal? AiSuggestedDeduction { get; set; }

        public DateTime? AiAnalyzedAt { get; set; }

        // Foreign Keys
        public int RentalId { get; set; }

        public string CreatedByUserId { get; set; } = string.Empty;

        // Navigation
        public Rental Rental { get; set; } = null!;

        public ApplicationUser CreatedByUser { get; set; } = null!;

        public ICollection<ConditionReportImage> Images { get; set; }
            = new List<ConditionReportImage>();
    }
}