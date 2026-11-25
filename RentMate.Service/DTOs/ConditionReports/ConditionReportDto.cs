namespace RentMate.Service.DTOs.ConditionReports
{
    public class ConditionReportDto
    {
        public int ConditionReportId { get; set; }

        public int RentalId { get; set; }

        public string ReportType { get; set; }
            = string.Empty;

        public string Condition { get; set; }
            = string.Empty;

        public string? Description { get; set; }

        public string CreatedByUserId { get; set; }
            = string.Empty;

        public DateTime CreatedAt { get; set; }

        public List<string> ImageUrls { get; set; }
            = new List<string>();

        // AI đánh giá (null khi chưa bật AI hoặc AI lỗi)
        public string? AiSummary { get; set; }

        public List<string> AiDamages { get; set; } = new();

        public string? AiSuggestedCondition { get; set; }

        public bool? AiNewDamageFound { get; set; }

        public bool? AiSameItem { get; set; }

        public decimal? AiSuggestedDeduction { get; set; }
    }
}