using RentMate.Core.Enums;

namespace RentMate.Core.ViewModels
{
    // Trang "Nạp / rút tiền": yêu cầu nạp và rút của khách
    public class WalletRequestListViewModel
    {
        public WalletTransactionType? Type { get; set; }
        public WalletTransactionStatus? Status { get; set; }
        public string? SearchTerm { get; set; }

        public int PendingDepositCount { get; set; }
        public int PendingWithdrawCount { get; set; }

        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 10;
        public int TotalCount { get; set; }
        public int TotalPages => Math.Max(1, (TotalCount + PageSize - 1) / PageSize);

        public List<WalletRequestItemViewModel> Requests { get; set; } = new();
    }

    public class WalletRequestItemViewModel
    {
        public int Id { get; set; }
        public WalletTransactionType Type { get; set; }
        public WalletTransactionStatus Status { get; set; }

        // Luôn là số dương để dễ đọc
        public decimal Amount { get; set; }

        // Mã nạp khách ghi trong nội dung chuyển khoản
        public string? Code { get; set; }
        public string? Note { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? ProcessedAt { get; set; }
        public string? ProcessedByName { get; set; }

        public string UserFullName { get; set; } = string.Empty;
        public string? UserEmail { get; set; }

        // Tài khoản nhận tiền khi rút (đầy đủ, chỉ Admin thấy)
        public string? BankName { get; set; }
        public string? BankAccountNumber { get; set; }
        public string? BankAccountName { get; set; }

        public string TypeText => Type == WalletTransactionType.Deposit ? "Nạp tiền" : "Rút tiền";

        public string StatusText => Status switch
        {
            WalletTransactionStatus.Pending => "Chờ xử lý",
            WalletTransactionStatus.Completed => "Đã xử lý",
            WalletTransactionStatus.Rejected => "Đã từ chối",
            _ => "Không xác định"
        };
    }
}
