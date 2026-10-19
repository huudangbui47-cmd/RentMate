namespace RentMate.Api.Models
{
    public class ConditionReportImage
    {
        public int ConditionReportImageId { get; set; }

        public string ImageUrl { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; }
            = DateTime.UtcNow;

        // Foreign Key
        public int ConditionReportId { get; set; }

        // Navigation
        public ConditionReport ConditionReport { get; set; } = null!;
    }
}