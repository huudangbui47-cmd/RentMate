using RentMate.Core.Enums;

namespace RentMate.Core.ViewModels
{
    public class PaymentViewModel
    {
        public int Id { get; set; }
        public int RentalId { get; set; }
        public string ItemName { get; set; } = string.Empty;
        public string RenterName { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public PaymentType PaymentType { get; set; }
        public PaymentMethod PaymentMethod { get; set; }
        public PaymentStatus Status { get; set; }
        public string? TransactionCode { get; set; }
        public DateTime? PaidAt { get; set; }
        public DateTime CreatedAt { get; set; }

        public string StatusText => Status switch
        {
            PaymentStatus.Pending => "Chờ thanh toán",
            PaymentStatus.Paid => "Đã thanh toán",
            PaymentStatus.Failed => "Thất bại",
            PaymentStatus.Refunded => "Đã hoàn tiền",
            _ => "Không xác định"
        };

        public string TypeText => PaymentType switch
        {
            PaymentType.RentalFee => "Phí thuê",
            PaymentType.Deposit => "Tiền cọc",
            PaymentType.DepositRefund => "Hoàn cọc",
            PaymentType.Compensation => "Bồi thường",
            _ => "Không xác định"
        };

        public string MethodText => PaymentMethod switch
        {
            PaymentMethod.Cash => "Tiền mặt",
            PaymentMethod.BankTransfer => "Chuyển khoản",
            PaymentMethod.OnlinePayment => "Thanh toán online",
            _ => "Không xác định"
        };
    }
}
