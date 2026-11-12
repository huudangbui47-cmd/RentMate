using RentMate.Service.DTOs.Wallet;

namespace RentMate.Service.Interfaces
{
    public interface IWalletService
    {
        // ===== Người dùng =====
        Task<WalletSummaryDto> GetSummaryAsync(string userId);

        Task<List<WalletTransactionDto>> GetHistoryAsync(string userId);

        Task<DepositRequestDto> CreateDepositAsync(string userId, decimal amount);

        Task UpdateBankInfoAsync(string userId, UpdateBankInfoDto dto);

        Task<WalletTransactionDto> CreateWithdrawAsync(string userId, decimal amount);

        // ===== Xác nhận nạp: dùng chung cho admin duyệt tay và webhook (sau này) =====
        Task ConfirmDepositAsync(string code, decimal receivedAmount, string? processedByUserId);

        // ===== Admin =====
        Task<List<WalletRequestForAdminDto>> GetPendingRequestsAsync();

        Task<bool> ApproveDepositAsync(int transactionId, string adminId);

        Task<bool> CompleteWithdrawAsync(int transactionId, string adminId);

        Task<bool> RejectRequestAsync(int transactionId, string adminId, string? reason);
    }
}
