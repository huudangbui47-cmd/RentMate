using System.Data;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Settings;
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
        private readonly IAuditLogService _auditLogService;
        private readonly INotificationService _notificationService;
        private readonly ISystemSettingService _settingService;

        public WalletService(
            IUnitOfWork unitOfWork,
            UserManager<ApplicationUser> userManager,
            IAuditLogService auditLogService,
            INotificationService notificationService,
            ISystemSettingService settingService)
        {
            _settingService = settingService;
            _unitOfWork = unitOfWork;
            _userManager = userManager;
            _auditLogService = auditLogService;
            _notificationService = notificationService;
        }

        // =========================
        // SỐ DƯ
        // =========================
        public async Task<WalletSummaryDto> GetSummaryAsync(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId)
                ?? throw new ArgumentException("Tài khoản không tồn tại.");

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
        public async Task<DepositRequestDto> CreateDepositAsync(string userId, decimal amount, int? rentalId = null, string? note = null)
        {
            // Giới hạn số tiền và số yêu cầu chờ lấy từ cài đặt hệ thống
            var settings = await _settingService.GetAsync();

            if (amount < settings.MinWalletAmount || amount > settings.MaxWalletAmount)
            {
                throw new ArgumentException(
                    $"Số tiền nạp từ {NotificationService.Money(settings.MinWalletAmount)} đến {NotificationService.Money(settings.MaxWalletAmount)}.");
            }

            var pendingDeposits = await _unitOfWork.WalletTransactions
                .BuildQuery(w =>
                    w.UserId == userId &&
                    w.Type == WalletTransactionType.Deposit &&
                    w.Status == WalletTransactionStatus.Pending &&
                    (w.Note == null || w.Note != VnPayService.OnlineNote))
                .CountAsync();

            // Nạp qua VNPay được xác nhận tự động nên không giới hạn như chuyển khoản tay
            if (note != VnPayService.OnlineNote && pendingDeposits >= settings.MaxPendingDeposits)
            {
                throw new InvalidOperationException(
                    $"Bạn đang có {settings.MaxPendingDeposits} yêu cầu nạp chờ duyệt. Hãy chuyển khoản theo mã đã tạo hoặc chờ quản trị viên xử lý.");
            }

            var transaction = new WalletTransaction
            {
                UserId = userId,
                Amount = amount,
                Type = WalletTransactionType.Deposit,
                Status = WalletTransactionStatus.Pending,
                Code = await GenerateUniqueCodeAsync(),
                RentalId = rentalId,
                Note = note
            };

            await _unitOfWork.WalletTransactions.AddAsync(transaction);
            await _unitOfWork.SaveChangesAsync();

            var deposit = new DepositRequestDto
            {
                TransactionId = transaction.Id,
                Code = transaction.Code!,
                Amount = transaction.Amount
            };

            FillReceiverInfo(deposit, settings);

            return deposit;
        }

        public async Task<DepositRequestDto?> GetPendingDepositAsync(string userId, int transactionId)
        {
            var deposit = await _unitOfWork.WalletTransactions
                .BuildQuery(w =>
                    w.Id == transactionId &&
                    w.UserId == userId &&
                    w.Type == WalletTransactionType.Deposit &&
                    w.Status == WalletTransactionStatus.Pending)
                .Select(w => new DepositRequestDto
                {
                    TransactionId = w.Id,
                    Code = w.Code!,
                    Amount = w.Amount
                })
                .FirstOrDefaultAsync();

            if (deposit != null)
                FillReceiverInfo(deposit, await _settingService.GetAsync());

            return deposit;
        }

        // Tài khoản nhận tiền của RentMate: quản trị viên nhập ở trang Cài đặt hệ thống.
        // Có mã ngân hàng VietQR thì kèm ảnh QR điền sẵn số tiền và nội dung chuyển khoản.
        private static void FillReceiverInfo(DepositRequestDto deposit, RentMateSettings settings)
        {
            deposit.ReceiverBankName = settings.BankName;
            deposit.ReceiverAccountNumber = settings.BankAccountNumber;
            deposit.ReceiverAccountName = settings.BankAccountName;

            if (!string.IsNullOrEmpty(settings.BankId) && !string.IsNullOrEmpty(settings.BankAccountNumber))
            {
                deposit.QrImageUrl =
                    $"https://img.vietqr.io/image/{Uri.EscapeDataString(settings.BankId)}-{Uri.EscapeDataString(settings.BankAccountNumber)}-compact2.png" +
                    $"?amount={deposit.Amount:0}" +
                    $"&addInfo={Uri.EscapeDataString(deposit.Code)}" +
                    $"&accountName={Uri.EscapeDataString(settings.BankAccountName ?? string.Empty)}";
            }
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
                ?? throw new ArgumentException("Mã nạp tiền không tồn tại.");

            var transaction = (await _unitOfWork.WalletTransactions.GetByIdAsync(transactionId))!;

            // Mỗi mã chỉ được xác nhận 1 lần
            if (transaction.Status != WalletTransactionStatus.Pending)
            {
                throw new InvalidOperationException("Yêu cầu nạp này đã được xử lý rồi.");
            }

            // Số tiền chuyển phải khớp số tiền yêu cầu
            if (receivedAmount != transaction.Amount)
            {
                throw new InvalidOperationException("Số tiền nhận được không khớp với số tiền yêu cầu.");
            }

            transaction.Status = WalletTransactionStatus.Completed;
            transaction.ProcessedByUserId = processedByUserId;
            transaction.ProcessedAt = DateTime.UtcNow;

            await _notificationService.AddAsync(transaction.UserId, NotificationType.Wallet,
                "Nạp tiền thành công",
                $"{NotificationService.Money(transaction.Amount)} đã được cộng vào ví (mã nạp {transaction.Code}).");

            await SaveProcessedAsync();
        }

        // =========================
        // THÔNG TIN NGÂN HÀNG
        // =========================
        public async Task UpdateBankInfoAsync(string userId, UpdateBankInfoDto dto)
        {
            var user = await _userManager.FindByIdAsync(userId)
                ?? throw new ArgumentException("Tài khoản không tồn tại.");

            // Không cho đổi tài khoản nhận khi đang có yêu cầu rút chờ xử lý
            var hasPendingWithdraw = await _unitOfWork.WalletTransactions
                .BuildQuery(w =>
                    w.UserId == userId &&
                    w.Type == WalletTransactionType.Withdraw &&
                    w.Status == WalletTransactionStatus.Pending)
                .AnyAsync();

            if (hasPendingWithdraw)
            {
                throw new InvalidOperationException("Bạn đang có yêu cầu rút tiền chờ xử lý, chưa đổi được tài khoản ngân hàng.");
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
            var settings = await _settingService.GetAsync();

            if (amount < settings.MinWalletAmount || amount > settings.MaxWalletAmount)
            {
                throw new ArgumentException(
                    $"Số tiền rút từ {NotificationService.Money(settings.MinWalletAmount)} đến {NotificationService.Money(settings.MaxWalletAmount)}.");
            }

            var user = await _userManager.FindByIdAsync(userId)
                ?? throw new ArgumentException("Tài khoản không tồn tại.");

            if (!HasBankInfo(user))
            {
                throw new InvalidOperationException("Vui lòng nhập thông tin ngân hàng trước khi rút tiền.");
            }

            // Serializable: 2 yêu cầu rút gửi cùng lúc không cùng qua được bước kiểm tra số dư
            await _unitOfWork.BeginTransactionAsync(IsolationLevel.Serializable);

            try
            {
                var (balance, pendingWithdraw) = await GetBalanceAsync(userId);

                if (amount > balance - pendingWithdraw)
                {
                    throw new InvalidOperationException("Số dư khả dụng không đủ.");
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
                await _unitOfWork.CommitTransactionAsync();

                return ToDto(transaction);
            }
            catch (DbUpdateException)
            {
                await _unitOfWork.RollbackTransactionAsync();
                throw new InvalidOperationException("Ví đang có giao dịch khác cùng lúc. Vui lòng thử lại.");
            }
            catch
            {
                await _unitOfWork.RollbackTransactionAsync();
                throw;
            }
        }

        // =========================
        // ADMIN: DANH SÁCH NẠP / RÚT
        // =========================
        public async Task<WalletRequestListViewModel> SearchRequestsAsync(
            WalletTransactionType? type, WalletTransactionStatus? status, string? searchTerm, int page = 1)
        {
            var query = _unitOfWork.WalletTransactions.BuildQuery(w =>
                w.Type == WalletTransactionType.Deposit || w.Type == WalletTransactionType.Withdraw);

            if (type.HasValue)
                query = query.Where(w => w.Type == type.Value);

            if (status.HasValue)
                query = query.Where(w => w.Status == status.Value);

            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                string keyword = searchTerm.Trim();

                query = query.Where(w =>
                    (w.Code != null && w.Code.Contains(keyword)) ||
                    w.User.FullName.Contains(keyword) ||
                    (w.User.Email != null && w.User.Email.Contains(keyword)));
            }

            int totalCount = await query.CountAsync();
            const int pageSize = 10;
            page = Math.Clamp(page, 1, Math.Max(1, (totalCount + pageSize - 1) / pageSize));

            // Đang xem yêu cầu chờ xử lý: cũ nhất lên đầu để xử lý trước
            var ordered = status == WalletTransactionStatus.Pending
                ? query.OrderBy(w => w.CreatedAt)
                : query.OrderByDescending(w => w.CreatedAt);

            var requests = await ordered
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(w => new WalletRequestItemViewModel
                {
                    Id = w.Id,
                    Type = w.Type,
                    Status = w.Status,
                    Amount = Math.Abs(w.Amount),
                    Code = w.Code,
                    Note = w.Note,
                    CreatedAt = w.CreatedAt,
                    ProcessedAt = w.ProcessedAt,
                    ProcessedByName = _userManager.Users
                        .Where(u => u.Id == w.ProcessedByUserId)
                        .Select(u => u.FullName)
                        .FirstOrDefault(),
                    UserFullName = w.User.FullName,
                    UserEmail = w.User.Email,
                    BankName = w.User.BankName,
                    BankAccountNumber = w.User.BankAccountNumber,
                    BankAccountName = w.User.BankAccountName
                })
                .ToListAsync();

            var pending = _unitOfWork.WalletTransactions
                .BuildQuery(w => w.Status == WalletTransactionStatus.Pending);

            return new WalletRequestListViewModel
            {
                Type = type,
                Status = status,
                SearchTerm = searchTerm,
                PendingDepositCount = await pending.CountAsync(w => w.Type == WalletTransactionType.Deposit),
                PendingWithdrawCount = await pending.CountAsync(w => w.Type == WalletTransactionType.Withdraw),
                Requests = requests,
                Page = page, PageSize = pageSize, TotalCount = totalCount
            };
        }

        // =========================
        // ADMIN: DUYỆT NẠP (đã thấy tiền vào tài khoản RentMate)
        // =========================
        public async Task ApproveDepositAsync(int transactionId, string adminId, string ipAddress)
        {
            var transaction = await _unitOfWork.WalletTransactions.GetByIdAsync(transactionId);

            if (transaction == null || transaction.Type != WalletTransactionType.Deposit)
                throw new InvalidOperationException("Yêu cầu nạp tiền không tồn tại.");

            await _auditLogService.RecordAsync("ApproveDeposit", "WalletTransaction", transaction.Id.ToString(),
                $"Duyệt nạp {NotificationService.Money(transaction.Amount)}, mã {transaction.Code}.", ipAddress, adminId);

            // Admin đã đối chiếu sao kê đúng số tiền yêu cầu; hàm này lưu luôn nhật ký ở trên
            await ConfirmDepositAsync(transaction.Code!, transaction.Amount, adminId);
        }

        // =========================
        // ADMIN: ĐÃ CHUYỂN KHOẢN RÚT
        // =========================
        public async Task CompleteWithdrawAsync(int transactionId, string adminId, string ipAddress)
        {
            var transaction = await _unitOfWork.WalletTransactions.GetByIdAsync(transactionId);

            if (transaction == null || transaction.Type != WalletTransactionType.Withdraw)
                throw new InvalidOperationException("Yêu cầu rút tiền không tồn tại.");

            if (transaction.Status != WalletTransactionStatus.Pending)
                throw new InvalidOperationException("Yêu cầu rút này đã được xử lý rồi.");

            transaction.Status = WalletTransactionStatus.Completed;
            transaction.ProcessedByUserId = adminId;
            transaction.ProcessedAt = DateTime.UtcNow;

            await _auditLogService.RecordAsync("CompleteWithdraw", "WalletTransaction", transaction.Id.ToString(),
                $"Xác nhận đã chuyển {NotificationService.Money(transaction.Amount)} cho yêu cầu rút #{transaction.Id}.", ipAddress, adminId);

            await _notificationService.AddAsync(transaction.UserId, NotificationType.Wallet,
                "Rút tiền thành công",
                $"RentMate đã chuyển {NotificationService.Money(transaction.Amount)} về tài khoản ngân hàng của bạn.");

            await SaveProcessedAsync();
        }

        // =========================
        // ADMIN: TỪ CHỐI NẠP / RÚT
        // =========================
        public async Task RejectRequestAsync(int transactionId, string adminId, string? reason, string ipAddress)
        {
            var transaction = await _unitOfWork.WalletTransactions.GetByIdAsync(transactionId);

            if (transaction == null ||
                (transaction.Type != WalletTransactionType.Deposit &&
                 transaction.Type != WalletTransactionType.Withdraw))
                throw new InvalidOperationException("Yêu cầu không tồn tại.");

            if (transaction.Status != WalletTransactionStatus.Pending)
                throw new InvalidOperationException("Yêu cầu này đã được xử lý rồi.");

            if (string.IsNullOrWhiteSpace(reason))
                throw new InvalidOperationException("Vui lòng nhập lý do từ chối để khách biết.");

            reason = reason.Trim();

            // Rút bị từ chối: tiền tự mở khóa vì dòng Rejected không còn được tính
            transaction.Status = WalletTransactionStatus.Rejected;
            transaction.ProcessedByUserId = adminId;
            transaction.ProcessedAt = DateTime.UtcNow;
            transaction.Note = reason.Length > 500 ? reason[..500] : reason;

            string typeText = transaction.Type == WalletTransactionType.Deposit ? "nạp" : "rút";

            await _auditLogService.RecordAsync("RejectWalletRequest", "WalletTransaction", transaction.Id.ToString(),
                $"Từ chối yêu cầu {typeText} {NotificationService.Money(transaction.Amount)} (#{transaction.Id}). Lý do: {transaction.Note}", ipAddress, adminId);

            await _notificationService.AddAsync(transaction.UserId, NotificationType.Wallet,
                $"Yêu cầu {typeText} tiền bị từ chối",
                $"Yêu cầu {typeText} {NotificationService.Money(transaction.Amount)} bị từ chối. Lý do: {transaction.Note}" +
                (transaction.Type == WalletTransactionType.Withdraw ? " Số tiền đã được mở khóa trong ví." : ""));

            await SaveProcessedAsync();
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
                    "Yêu cầu này vừa được người khác xử lý. Vui lòng tải lại trang.");
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
