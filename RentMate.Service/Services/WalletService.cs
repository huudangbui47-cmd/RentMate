using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Service.DTOs.Wallet;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class WalletService : IWalletService
    {
        private const string CodePrefix = "RM";
        // Bỏ 0/O, 1/I để người dùng không gõ nhầm mã nạp
        private const string CodeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

        private readonly IUnitOfWork _unitOfWork;
        private readonly UserManager<ApplicationUser> _userManager;

        public WalletService(
            IUnitOfWork unitOfWork,
            UserManager<ApplicationUser> userManager)
        {
            _unitOfWork = unitOfWork;
            _userManager = userManager;
        }

        // =========================
        // SỐ DƯ
        // =========================
        public async Task<WalletSummaryDto> GetSummaryAsync(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId)
                ?? throw new ArgumentException("User does not exist.");

            var (balance, pendingWithdraw) = await GetBalanceAsync(userId);

            return new WalletSummaryDto
            {
                Balance = balance,
                PendingWithdrawAmount = pendingWithdraw,
                AvailableBalance = balance - pendingWithdraw,
                HasBankInfo = HasBankInfo(user),
                BankName = user.BankName,
                BankAccountName = user.BankAccountName,
                MaskedAccountNumber = Mask(user.BankAccountNumber)
            };
        }

        public async Task<decimal> GetAvailableBalanceAsync(string userId)
        {
            var (balance, pendingWithdraw) = await GetBalanceAsync(userId);
            return balance - pendingWithdraw;
        }

        // =========================
        // LỊCH SỬ
        // =========================
        public async Task<List<WalletTransactionDto>> GetHistoryAsync(string userId)
        {
            var transactions = await _unitOfWork.WalletTransactions
                .BuildQuery(w => w.UserId == userId)
                .OrderByDescending(w => w.CreatedAt)
                .ToListAsync();

            return transactions.Select(ToDto).ToList();
        }

        // =========================
        // TẠO YÊU CẦU NẠP
        // =========================
        public async Task<DepositRequestDto> CreateDepositAsync(string userId, decimal amount)
        {
            if (amount < 10_000 || amount > 50_000_000)
            {
                throw new ArgumentException("Deposit amount must be between 10,000 and 50,000,000.");
            }

            var transaction = new WalletTransaction
            {
                UserId = userId,
                Amount = amount,
                Type = WalletTransactionType.Deposit,
                Status = WalletTransactionStatus.Pending,
                Code = await GenerateUniqueCodeAsync()
            };

            await _unitOfWork.WalletTransactions.AddAsync(transaction);
            await _unitOfWork.SaveChangesAsync();

            return new DepositRequestDto
            {
                TransactionId = transaction.Id,
                Code = transaction.Code!,
                Amount = transaction.Amount
            };
        }

        // =========================
        // XÁC NHẬN NẠP (admin duyệt tay / webhook dùng chung)
        // =========================
        public async Task ConfirmDepositAsync(string code, decimal receivedAmount, string? processedByUserId)
        {
            var normalizedCode = code.Trim().ToUpperInvariant();

            // BuildQuery không tracking: chỉ dùng để tìm Id, rồi lấy bản có tracking bằng GetByIdAsync để lưu được
            var transactionId = await _unitOfWork.WalletTransactions
                .BuildQuery(w =>
                    w.Code == normalizedCode &&
                    w.Type == WalletTransactionType.Deposit)
                .Select(w => (int?)w.Id)
                .FirstOrDefaultAsync()
                ?? throw new ArgumentException("Deposit code does not exist.");

            var transaction = (await _unitOfWork.WalletTransactions.GetByIdAsync(transactionId))!;

            // Mỗi mã chỉ được xác nhận 1 lần
            if (transaction.Status != WalletTransactionStatus.Pending)
            {
                throw new InvalidOperationException("This deposit has already been processed.");
            }

            // Số tiền chuyển phải khớp số tiền yêu cầu
            if (receivedAmount != transaction.Amount)
            {
                throw new InvalidOperationException("Received amount does not match the requested amount.");
            }

            transaction.Status = WalletTransactionStatus.Completed;
            transaction.ProcessedByUserId = processedByUserId;
            transaction.ProcessedAt = DateTime.UtcNow;

            await SaveProcessedAsync();
        }

        // =========================
        // THÔNG TIN NGÂN HÀNG
        // =========================
        public async Task UpdateBankInfoAsync(string userId, UpdateBankInfoDto dto)
        {
            var user = await _userManager.FindByIdAsync(userId)
                ?? throw new ArgumentException("User does not exist.");

            // Không cho đổi tài khoản nhận khi đang có yêu cầu rút chờ xử lý
            var hasPendingWithdraw = await _unitOfWork.WalletTransactions
                .BuildQuery(w =>
                    w.UserId == userId &&
                    w.Type == WalletTransactionType.Withdraw &&
                    w.Status == WalletTransactionStatus.Pending)
                .AnyAsync();

            if (hasPendingWithdraw)
            {
                throw new InvalidOperationException("Cannot change bank info while a withdrawal is pending.");
            }

            user.BankName = dto.BankName.Trim();
            user.BankAccountNumber = dto.BankAccountNumber.Trim();
            user.BankAccountName = NormalizeName(dto.BankAccountName);

            var result = await _userManager.UpdateAsync(user);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(" ", result.Errors.Select(e => e.Description)));
            }
        }

        // =========================
        // TẠO YÊU CẦU RÚT
        // =========================
        public async Task<WalletTransactionDto> CreateWithdrawAsync(string userId, decimal amount)
        {
            if (amount < 10_000 || amount > 50_000_000)
            {
                throw new ArgumentException("Withdraw amount must be between 10,000 and 50,000,000.");
            }

            var user = await _userManager.FindByIdAsync(userId)
                ?? throw new ArgumentException("User does not exist.");

            if (!HasBankInfo(user))
            {
                throw new InvalidOperationException("Please add your bank information before withdrawing.");
            }

            var (balance, pendingWithdraw) = await GetBalanceAsync(userId);

            // shortcut: 2 yêu cầu rút gửi đúng cùng lúc có thể cùng qua bước kiểm tra này; cần khóa ví (transaction Serializable) nếu dùng thật.
            if (amount > balance - pendingWithdraw)
            {
                throw new InvalidOperationException("Insufficient available balance.");
            }

            // Lưu số âm, trạng thái Pending: số tiền bị khóa ngay, chưa trừ khỏi Balance
            var transaction = new WalletTransaction
            {
                UserId = userId,
                Amount = -amount,
                Type = WalletTransactionType.Withdraw,
                Status = WalletTransactionStatus.Pending,
                Note = $"Rút về {user.BankName} {Mask(user.BankAccountNumber)}"
            };

            await _unitOfWork.WalletTransactions.AddAsync(transaction);
            await _unitOfWork.SaveChangesAsync();

            return ToDto(transaction);
        }

        // =========================
        // ADMIN: DANH SÁCH CHỜ XỬ LÝ
        // =========================
        public async Task<List<WalletRequestForAdminDto>> GetPendingRequestsAsync()
        {
            return await _unitOfWork.WalletTransactions
                .BuildQuery(w =>
                    w.Status == WalletTransactionStatus.Pending &&
                    (w.Type == WalletTransactionType.Deposit ||
                     w.Type == WalletTransactionType.Withdraw))
                .OrderBy(w => w.CreatedAt)
                .Select(w => new WalletRequestForAdminDto
                {
                    TransactionId = w.Id,
                    Type = w.Type.ToString(),
                    Status = w.Status.ToString(),
                    Amount = Math.Abs(w.Amount),
                    Code = w.Code,
                    CreatedAt = w.CreatedAt,
                    UserId = w.UserId,
                    UserFullName = w.User.FullName,
                    UserEmail = w.User.Email,
                    BankName = w.User.BankName,
                    BankAccountNumber = w.User.BankAccountNumber,
                    BankAccountName = w.User.BankAccountName
                })
                .ToListAsync();
        }

        // =========================
        // ADMIN: DUYỆT NẠP
        // =========================
        public async Task<bool> ApproveDepositAsync(int transactionId, string adminId)
        {
            var transaction = await _unitOfWork.WalletTransactions.GetByIdAsync(transactionId);

            if (transaction == null || transaction.Type != WalletTransactionType.Deposit)
            {
                return false;
            }

            // Admin đã đối chiếu sao kê đúng số tiền yêu cầu
            await ConfirmDepositAsync(transaction.Code!, transaction.Amount, adminId);

            return true;
        }

        // =========================
        // ADMIN: ĐÃ CHUYỂN KHOẢN RÚT
        // =========================
        public async Task<bool> CompleteWithdrawAsync(int transactionId, string adminId)
        {
            var transaction = await _unitOfWork.WalletTransactions.GetByIdAsync(transactionId);

            if (transaction == null || transaction.Type != WalletTransactionType.Withdraw)
            {
                return false;
            }

            if (transaction.Status != WalletTransactionStatus.Pending)
            {
                throw new InvalidOperationException("This withdrawal has already been processed.");
            }

            transaction.Status = WalletTransactionStatus.Completed;
            transaction.ProcessedByUserId = adminId;
            transaction.ProcessedAt = DateTime.UtcNow;

            await SaveProcessedAsync();

            return true;
        }

        // =========================
        // ADMIN: TỪ CHỐI NẠP / RÚT
        // =========================
        public async Task<bool> RejectRequestAsync(int transactionId, string adminId, string? reason)
        {
            var transaction = await _unitOfWork.WalletTransactions.GetByIdAsync(transactionId);

            if (transaction == null ||
                (transaction.Type != WalletTransactionType.Deposit &&
                 transaction.Type != WalletTransactionType.Withdraw))
            {
                return false;
            }

            if (transaction.Status != WalletTransactionStatus.Pending)
            {
                throw new InvalidOperationException("This request has already been processed.");
            }

            // Rút bị từ chối: tiền tự mở khóa vì dòng Rejected không còn được tính
            transaction.Status = WalletTransactionStatus.Rejected;
            transaction.ProcessedByUserId = adminId;
            transaction.ProcessedAt = DateTime.UtcNow;

            if (!string.IsNullOrWhiteSpace(reason))
            {
                transaction.Note = reason.Trim();
            }

            await SaveProcessedAsync();

            return true;
        }

        // =========================
        // HELPERS
        // =========================

        // Balance = tổng các dòng Completed; pendingWithdraw = tổng tiền đang chờ rút (số dương)
        private async Task<(decimal balance, decimal pendingWithdraw)> GetBalanceAsync(string userId)
        {
            var balance = await _unitOfWork.WalletTransactions
                .BuildQuery(w =>
                    w.UserId == userId &&
                    w.Status == WalletTransactionStatus.Completed)
                .SumAsync(w => (decimal?)w.Amount) ?? 0;

            var pendingWithdraw = await _unitOfWork.WalletTransactions
                .BuildQuery(w =>
                    w.UserId == userId &&
                    w.Type == WalletTransactionType.Withdraw &&
                    w.Status == WalletTransactionStatus.Pending)
                .SumAsync(w => (decimal?)w.Amount) ?? 0;

            return (balance, -pendingWithdraw);
        }

        // Hai người xử lý cùng lúc: người thứ hai bị báo lỗi thay vì ghi đè
        private async Task SaveProcessedAsync()
        {
            try
            {
                await _unitOfWork.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                throw new InvalidOperationException(
                    "This request was just processed by someone else. Please reload.");
            }
        }

        private async Task<string> GenerateUniqueCodeAsync()
        {
            while (true)
            {
                var code = CodePrefix + RandomNumberGenerator.GetString(CodeChars, 6);

                var exists = await _unitOfWork.WalletTransactions
                    .BuildQuery(w => w.Code == code)
                    .AnyAsync();

                if (!exists)
                {
                    return code;
                }
            }
        }

        private static bool HasBankInfo(ApplicationUser user) =>
            !string.IsNullOrWhiteSpace(user.BankName) &&
            !string.IsNullOrWhiteSpace(user.BankAccountNumber) &&
            !string.IsNullOrWhiteSpace(user.BankAccountName);

        private static string? Mask(string? accountNumber) =>
            string.IsNullOrEmpty(accountNumber) || accountNumber.Length <= 4
                ? accountNumber
                : "****" + accountNumber[^4..];

        // "Nguyễn  Văn Ân" -> "NGUYEN VAN AN" (giống tên ngân hàng hiển thị)
        public static string NormalizeName(string name)
        {
            var decomposed = name.Trim()
                .Replace('đ', 'd').Replace('Đ', 'D')
                .Normalize(NormalizationForm.FormD);

            var sb = new StringBuilder();
            foreach (var c in decomposed)
            {
                if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                {
                    sb.Append(c);
                }
            }

            var words = sb.ToString()
                .Normalize(NormalizationForm.FormC)
                .ToUpperInvariant()
                .Split(' ', StringSplitOptions.RemoveEmptyEntries);

            return string.Join(' ', words);
        }

        private static WalletTransactionDto ToDto(WalletTransaction w) => new()
        {
            TransactionId = w.Id,
            Amount = w.Amount,
            Type = w.Type.ToString(),
            Status = w.Status.ToString(),
            Code = w.Code,
            RentalId = w.RentalId,
            Note = w.Note,
            CreatedAt = w.CreatedAt,
            ProcessedAt = w.ProcessedAt
        };
    }
}
