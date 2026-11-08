namespace RentMate.Api.DTOs.Payments
{
    public class PaymentDto
    {
        public int PaymentId { get; set; }

        public int RentalId { get; set; }

        public decimal Amount { get; set; }

        public string PaymentType { get; set; }
            = string.Empty;

        public string PaymentMethod { get; set; }
            = string.Empty;

        public string PaymentStatus { get; set; }
            = string.Empty;

        public string? TransactionCode { get; set; }

        public DateTime? PaidAt { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}