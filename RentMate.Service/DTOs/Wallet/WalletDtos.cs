using System.ComponentModel.DataAnnotations;

namespace RentMate.Service.DTOs.Wallet
{
    public class WalletSummaryDto
    {
        // Tổng tiền đã ghi nhận trong ví
        public decimal Balance { get; set; }

        // Số dư dùng được = Balance - tiền đang chờ rút
        public decimal AvailableBalance { get; set; }

        public decimal PendingWithdrawAmount { get; set; }

        public bool HasBankInfo { get; set; }

        public string? BankName { get; set; }

        public string? BankAccountName { get; set; }

        // Chỉ hiện 4 số cuối: ****6789
        public string? MaskedAccountNumber { get; set; }
    }

    public class WalletTransactionDto
    {
        public int TransactionId { get; set; }

        public decimal Amount { get; set; }

        public string Type { get; set; } = string.Empty;

        public string Status { get; set; } = string.Empty;

        public string? Code { get; set; }

        public int? RentalId { get; set; }

        public string? Note { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? ProcessedAt { get; set; }
    }

    public class CreateDepositDto
    {
        [Range(10_000, 50_000_000, ErrorMessage = "Số tiền nạp từ 10.000 đến 50.000.000 đ.")]
        public decimal Amount { get; set; }
    }

    public class DepositRequestDto
    {
        public int TransactionId { get; set; }

        public string Code { get; set; } = string.Empty;

        public decimal Amount { get; set; }

        // Tài khoản nhận tiền của RentMate (lấy từ appsettings, controller điền)
        public string? ReceiverBankName { get; set; }

        public string? ReceiverAccountNumber { get; set; }

        public string? ReceiverAccountName { get; set; }

        // Ảnh mã QR VietQR đã điền sẵn số tiền + nội dung
        public string? QrImageUrl { get; set; }
    }

    public class UpdateBankInfoDto
    {
        [Required(ErrorMessage = "Vui lòng nhập tên ngân hàng.")]
        [MaxLength(100)]
        public string BankName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập số tài khoản.")]
        [RegularExpression(@"^\d{6,20}$", ErrorMessage = "Số tài khoản chỉ gồm 6–20 chữ số.")]
        public string BankAccountNumber { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập họ tên chủ tài khoản.")]
        [MaxLength(100)]
        public string BankAccountName { get; set; } = string.Empty;
    }

    public class CreateWithdrawDto
    {
        [Range(10_000, 50_000_000, ErrorMessage = "Số tiền rút từ 10.000 đến 50.000.000 đ.")]
        public decimal Amount { get; set; }
    }
}
