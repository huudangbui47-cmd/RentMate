using RentMate.Core.Enums;

namespace RentMate.Service.DTOs.ConditionReports
{
    public class CreateConditionReportDto
    {
        public ConditionReportType ReportType { get; set; }

        public ItemCondition Condition { get; set; }

        public string? Description { get; set; }

        // Ảnh gửi kèm dạng multipart (field "files"), không còn nhận link ảnh gõ tay
    }
}