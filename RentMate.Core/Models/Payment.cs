using RentMate.Core.Enums;

namespace RentMate.Core.Models
{
    public class Payment : BaseEntity
    {
        public decimal Amount { get; set; }

        public PaymentType PaymentType { get; set; }

        public PaymentMethod PaymentMethod { get; set; }

        public PaymentStatus Status { get; set; }
            = PaymentStatus.Pending;

        public string? TransactionCode { get; set; }

        public DateTime? PaidAt { get; set; }

        public DateTime CreatedAt { get; set; }
            = DateTime.UtcNow;

        // Foreign Key
        public int RentalId { get; set; }

        // Navigation
        public Rental Rental { get; set; } = null!;
    }
}