namespace RentMate.Core.Models
{
    public class ConditionReportImage : BaseEntity
    {
        public string ImageUrl { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; }
            = DateTime.UtcNow;

        // Foreign Key
        public int ConditionReportId { get; set; }

        // Navigation
        public ConditionReport ConditionReport { get; set; } = null!;
    }
}