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