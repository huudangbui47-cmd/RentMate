using RentMate.Api.Models.Enums;

namespace RentMate.Api.DTOs.Payments
{
    public class PayPaymentDto
    {
        public PaymentType PaymentType { get; set; }

        public PaymentMethod PaymentMethod { get; set; }

        public string? TransactionCode { get; set; }
    }
}