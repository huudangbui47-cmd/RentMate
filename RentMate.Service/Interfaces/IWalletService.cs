using RentMate.Core.Enums;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Wallet;

namespace RentMate.Service.Interfaces
{
    public interface IWalletService
    {
        // ===== Người dùng =====
        Task<WalletSummaryDto> GetSummaryAsync(string userId);

        Task<List<WalletTransactionDto>> GetHistoryAsync(string userId);

        // Số dư dùng được (đã trừ tiền đang chờ rút) – RentalService dùng khi thanh toán đơn
        Task<decimal> GetAvailableBalanceAsync(string userId);

        Task<DepositRequestDto> CreateDepositAsync(string userId, decimal amount);

        // Yêu cầu nạp đang chờ của chính người dùng (null nếu không có / đã xử lý)
        Task<DepositRequestDto?> GetPendingDepositAsync(string userId, int transactionId);

        Task UpdateBankInfoAsync(string userId, UpdateBankInfoDto dto);

        Task<WalletTransactionDto> CreateWithdrawAsync(string userId, decimal amount);

        // ===== Xác nhận nạp: dùng chung cho admin duyệt tay và webhook (sau này) =====
        Task ConfirmDepositAsync(string code, decimal receivedAmount, string? processedByUserId);

        // ===== Admin (trang quản trị) =====
        Task<WalletRequestListViewModel> SearchRequestsAsync(WalletTransactionType? type, WalletTransactionStatus? status, string? searchTerm, int page = 1);

        Task ApproveDepositAsync(int transactionId, string adminId, string ipAddress);

        Task CompleteWithdrawAsync(int transactionId, string adminId, string ipAddress);

        Task RejectRequestAsync(int transactionId, string adminId, string? reason, string ipAddress);
    }
}
