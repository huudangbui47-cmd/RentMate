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

        public string ReportTypeText => ReportType switch
        {
            ConditionReportType.BeforeRental => "Trước khi thuê",
            ConditionReportType.AfterRental => "Sau khi trả",
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
