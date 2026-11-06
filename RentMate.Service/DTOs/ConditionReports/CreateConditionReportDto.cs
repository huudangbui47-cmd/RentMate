using RentMate.Core.Enums;

namespace RentMate.Service.DTOs.ConditionReports
{
    public class CreateConditionReportDto
    {
        public ConditionReportType ReportType { get; set; }

        public ItemCondition Condition { get; set; }

        public string? Description { get; set; }

        public List<string> ImageUrls { get; set; }
            = new List<string>();
    }
}