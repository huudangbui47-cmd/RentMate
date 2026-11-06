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
    }
}