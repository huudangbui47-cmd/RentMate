using RentMate.Core.Enums;

namespace RentMate.Core.Models
{
    public class Rental : BaseEntity
    {
        public DateTime StartDate { get; set; }

        public DateTime EndDate { get; set; }

        public decimal PricePerDay { get; set; }

        public decimal DepositAmount { get; set; }

        public decimal TotalPrice { get; set; }

        public string? RequestNote { get; set; }

        public RentalStatus Status { get; set; }
            = RentalStatus.Pending;

        public DateTime RequestedAt { get; set; }
            = DateTime.UtcNow;

        public DateTime? ApprovedAt { get; set; }

        public DateTime? ReceivedAt { get; set; }

        public DateTime? ReturnedAt { get; set; }

        public DateTime? CompletedAt { get; set; }

        // Bồi thường hư hỏng: trừ vào tiền cọc, chủ đồ nhận phần này
        public decimal DamageAmount { get; set; }

        public string? DamageNote { get; set; }

        public DateTime? DamageClaimedAt { get; set; }

        // Người thuê khiếu nại mức bồi thường, quản trị viên phân xử
        public string? DisputeReason { get; set; }

        public DateTime? DisputedAt { get; set; }

        public string? ResolutionNote { get; set; }

        // Foreign Keys
        public int ItemId { get; set; }

        public string RenterId { get; set; } = string.Empty;

        // Navigation
        public Item Item { get; set; } = null!;

        public ApplicationUser Renter { get; set; } = null!;

        public ICollection<Payment> Payments { get; set; }
            = new List<Payment>();

        public ICollection<ConditionReport> ConditionReports { get; set; }
            = new List<ConditionReport>();

        public ICollection<Review> Reviews { get; set; }
            = new List<Review>();
    }
}