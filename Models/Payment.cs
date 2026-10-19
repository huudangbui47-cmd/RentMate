using RentMate.Api.Models.Enums;

namespace RentMate.Api.Models
{
    public class Payment
    {
        public int PaymentId { get; set; }

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