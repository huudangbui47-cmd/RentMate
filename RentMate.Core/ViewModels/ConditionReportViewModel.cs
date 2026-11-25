using RentMate.Core.Enums;

namespace RentMate.Core.ViewModels
{
    public class ConditionReportViewModel
    {
        public int Id { get; set; }
        public ConditionReportType ReportType { get; set; }
        public ItemCondition Condition { get; set; }
        public string? Description { get; set; }
        public string CreatedByName { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public List<string> ImageUrls { get; set; } = new();

        public string? AiSummary { get; set; }
        public string? AiDamages { get; set; }
        public ItemCondition? AiSuggestedCondition { get; set; }
        public bool? AiNewDamageFound { get; set; }
        public bool? AiSameItem { get; set; }
        public decimal? AiSuggestedDeduction { get; set; }

        public List<string> AiDamageList => string.IsNullOrWhiteSpace(AiDamages)
            ? new List<string>()
            : AiDamages.Split('\n', StringSplitOptions.RemoveEmptyEntries).ToList();

        public string? AiConditionText => AiSuggestedCondition switch
        {
            ItemCondition.New => "Mới",
            ItemCondition.LikeNew => "Như mới",
            ItemCondition.Good => "Tốt",
            ItemCondition.Fair => "Khá",
            ItemCondition.Damaged => "Hư hỏng",
            _ => null
        };

        public string ReportTypeText => ReportType switch
        {
            ConditionReportType.BeforeRental => "Chủ đồ giao đồ",
            ConditionReportType.AfterRental => "Chủ đồ nhận lại",
            ConditionReportType.RenterReceived => "Người thuê nhận đồ",
            _ => "Không xác định"
        };

        public string ConditionText => Condition switch
        {
            ItemCondition.New => "Mới",
            ItemCondition.LikeNew => "Như mới",
            ItemCondition.Good => "Tốt",
            ItemCondition.Fair => "Khá",
            ItemCondition.Damaged => "Hư hỏng",
            _ => "Không xác định"
        };
    }
}
