using RentMate.Core.Enums;

namespace RentMate.Core.Models
{
    /// <summary>
    /// Sổ giao dịch ví: mỗi lần tiền trong ví thay đổi là một dòng.
    /// Số dư = tổng Amount của các dòng Completed (tiền vào dương, tiền ra âm).
    /// </summary>
    public class WalletTransaction : BaseEntity
    {
        public string UserId { get; set; } = string.Empty;

        // Dương: tiền vào ví. Âm: tiền ra khỏi ví.
        public decimal Amount { get; set; }

        public WalletTransactionType Type { get; set; }

        public WalletTransactionStatus Status { get; set; }
            = WalletTransactionStatus.Pending;

        // Mã nạp (ví dụ RM8F3K2), ghi trong nội dung chuyển khoản. Chỉ có ở giao dịch nạp.
        public string? Code { get; set; }

        // Đơn thuê liên quan (thanh toán, hoàn cọc...). Nạp/rút thì để null.
        public int? RentalId { get; set; }

        public string? Note { get; set; }

        // Admin đã duyệt / từ chối
        public string? ProcessedByUserId { get; set; }

        public DateTime? ProcessedAt { get; set; }

        public DateTime CreatedAt { get; set; }
            = DateTime.UtcNow;

        // Chống 2 người (admin + webhook) xử lý cùng một giao dịch cùng lúc
        public byte[] RowVersion { get; set; } = Array.Empty<byte>();

        // Navigation
        public ApplicationUser User { get; set; } = null!;

        public Rental? Rental { get; set; }
    }
}
