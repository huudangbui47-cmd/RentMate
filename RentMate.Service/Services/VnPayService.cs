using System.Globalization;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Service.DTOs;
using RentMate.Service.DTOs.Wallet;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    // Nạp ví qua VNPay. Mã nạp (RMxxxxxx) chính là mã giao dịch gửi sang VNPay (vnp_TxnRef),
    // VNPay báo thành công thì cộng ví ngay, không cần quản trị viên duyệt tay.
    public class VnPayService : IVnPayService
    {
        public const string OnlineNote = "VNPay";

        private readonly VnPaySettings _settings;
        private readonly IUnitOfWork _unitOfWork;
        private readonly IWalletService _walletService;
        private readonly IRentalService _rentalService;
        private readonly INotificationService _notificationService;
        private readonly ILogger<VnPayService> _logger;
        private readonly ISystemSettingService _settingService;

        public VnPayService(
            IOptions<VnPaySettings> options,
            IUnitOfWork unitOfWork,
            IWalletService walletService,
            IRentalService rentalService,
            INotificationService notificationService,
            ILogger<VnPayService> logger,
            ISystemSettingService settingService)
        {
            _settingService = settingService;
            _settings = options.Value;
            _unitOfWork = unitOfWork;
            _walletService = walletService;
            _rentalService = rentalService;
            _notificationService = notificationService;
            _logger = logger;
        }

        public bool IsEnabled =>
            !string.IsNullOrWhiteSpace(_settings.TmnCode) && !string.IsNullOrWhiteSpace(_settings.HashSecret);

        public async Task<VnPayPaymentDto> CreatePaymentAsync(string userId, CreateVnPayPaymentDto dto, string ipAddress)
        {
            if (!IsEnabled)
                throw new InvalidOperationException("Chưa bật thanh toán VNPay. Vui lòng nạp bằng chuyển khoản.");

            decimal amount;

            if (dto.RentalId != null)
            {
                // Nạp đúng số còn thiếu để trả đơn (server tự tính, không tin số app gửi)
                var rental = await _unitOfWork.Rentals
                    .BuildQuery(r => r.Id == dto.RentalId)
                    .Select(r => new { r.RenterId, r.Status, Total = r.TotalPrice + r.DepositAmount })
                    .FirstOrDefaultAsync()
                    ?? throw new ArgumentException("Đơn thuê không tồn tại.");

                if (rental.RenterId != userId)
                    throw new UnauthorizedAccessException();

                if (rental.Status != RentalStatus.Approved)
                    throw new InvalidOperationException("Chỉ thanh toán được đơn đã được chủ đồ duyệt.");

                var missing = rental.Total - await _walletService.GetAvailableBalanceAsync(userId);

                if (missing <= 0)
                    throw new InvalidOperationException("Ví đã đủ tiền, bạn có thể thanh toán ngay.");

                // Không nạp ít hơn mức tối thiểu trong cài đặt (VNPay cũng nhận tối thiểu 10.000 đ); làm tròn lên nghìn đồng
                int minAmount = Math.Max(10_000, (await _settingService.GetAsync()).MinWalletAmount);
                amount = Math.Max(minAmount, Math.Ceiling(missing / 1000m) * 1000m);
            }
            else
            {
                amount = dto.Amount ?? throw new ArgumentException("Vui lòng nhập số tiền nạp.");
            }

            var deposit = await _walletService.CreateDepositAsync(userId, amount, dto.RentalId, OnlineNote);

            var now = DateTime.UtcNow.AddHours(7); // VNPay dùng giờ Việt Nam

            var data = new SortedDictionary<string, string>(StringComparer.Ordinal)
            {
                ["vnp_Version"] = "2.1.0",
                ["vnp_Command"] = "pay",
                ["vnp_TmnCode"] = _settings.TmnCode!,
                ["vnp_Amount"] = ((long)(deposit.Amount * 100)).ToString(CultureInfo.InvariantCulture),
                ["vnp_CreateDate"] = now.ToString("yyyyMMddHHmmss"),
                ["vnp_ExpireDate"] = now.AddMinutes(15).ToString("yyyyMMddHHmmss"),
                ["vnp_CurrCode"] = "VND",
                ["vnp_IpAddr"] = ipAddress.Contains(':') ? "127.0.0.1" : ipAddress,
                ["vnp_Locale"] = "vn",
                ["vnp_OrderInfo"] = dto.RentalId != null
                    ? $"Nap vi RentMate {deposit.Code} thanh toan don {dto.RentalId}"
                    : $"Nap vi RentMate {deposit.Code}",
                ["vnp_OrderType"] = "other",
                ["vnp_ReturnUrl"] = _settings.ReturnUrl,
                ["vnp_TxnRef"] = deposit.Code
            };

            string query = BuildQuery(data);

            return new VnPayPaymentDto
            {
                PaymentUrl = $"{_settings.PaymentUrl}?{query}&vnp_SecureHash={Sign(query)}",
                Code = deposit.Code,
                Amount = deposit.Amount
            };
        }

        public async Task<VnPayCallbackResult> ProcessCallbackAsync(IDictionary<string, string> query)
        {
            if (!IsEnabled)
                return Fail("99", "Chưa bật thanh toán VNPay.");

            // 1. Kiểm tra chữ ký: chặn người khác tự gõ link "thanh toán thành công"
            var data = new SortedDictionary<string, string>(StringComparer.Ordinal);

            foreach (var (key, value) in query)
            {
                if (key.StartsWith("vnp_", StringComparison.Ordinal) &&
                    key != "vnp_SecureHash" && key != "vnp_SecureHashType" &&
                    !string.IsNullOrEmpty(value))
                {
                    data[key] = value;
                }
            }

            query.TryGetValue("vnp_SecureHash", out var receivedHash);

            if (string.IsNullOrEmpty(receivedHash) ||
                !string.Equals(Sign(BuildQuery(data)), receivedHash, StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogWarning("VNPay gửi về chữ ký không hợp lệ.");
                return Fail("97", "Chữ ký không hợp lệ.");
            }

            data.TryGetValue("vnp_TxnRef", out var code);
            data.TryGetValue("vnp_ResponseCode", out var responseCode);
            data.TryGetValue("vnp_TransactionStatus", out var transactionStatus);
            data.TryGetValue("vnp_Amount", out var amountText);

            // 2. Tìm yêu cầu nạp theo mã
            var transactionId = await _unitOfWork.WalletTransactions
                .BuildQuery(w => w.Code == code && w.Type == WalletTransactionType.Deposit)
                .Select(w => (int?)w.Id)
                .FirstOrDefaultAsync();

            if (transactionId == null)
                return Fail("01", "Không tìm thấy yêu cầu nạp.");

            var transaction = (await _unitOfWork.WalletTransactions.GetByIdAsync(transactionId.Value))!;

            // VNPay có thể báo 2 lần (trang trả về + IPN): lần sau chỉ báo lại kết quả
            if (transaction.Status != WalletTransactionStatus.Pending)
            {
                return transaction.Status == WalletTransactionStatus.Completed
                    ? new VnPayCallbackResult { Success = true, RspCode = "02", Message = "Giao dịch đã được ghi nhận trước đó." }
                    : Fail("02", "Giao dịch đã bị hủy hoặc không thành công.");
            }

            if (!long.TryParse(amountText, out var amountX100) || amountX100 / 100m != transaction.Amount)
                return Fail("04", "Số tiền không khớp với yêu cầu nạp.");

            // 3. Không thành công (người dùng hủy, thẻ lỗi...): đóng yêu cầu nạp
            if (responseCode != "00" || transactionStatus != "00")
            {
                transaction.Status = WalletTransactionStatus.Rejected;
                transaction.ProcessedAt = DateTime.UtcNow;
                transaction.Note = $"{OnlineNote}: không thành công (mã {responseCode})";
                await _unitOfWork.SaveChangesAsync();

                return new VnPayCallbackResult
                {
                    Success = false,
                    RspCode = "00", // đã nhận kết quả
                    Message = responseCode == "24" ? "Bạn đã hủy thanh toán." : $"Thanh toán không thành công (mã lỗi {responseCode})."
                };
            }

            // 4. Thành công: cộng ví (dùng chung hàm với admin duyệt tay)
            try
            {
                await _walletService.ConfirmDepositAsync(transaction.Code!, transaction.Amount, null);
            }
            catch (InvalidOperationException)
            {
                // Lần báo kia vừa xử lý xong
                return new VnPayCallbackResult { Success = true, RspCode = "02", Message = "Giao dịch đã được ghi nhận trước đó." };
            }

            string message = $"Đã nạp {NotificationService.Money(transaction.Amount)} vào ví RentMate.";

            // 5. Nạp để trả đơn: trả tiền đơn luôn
            if (transaction.RentalId != null)
            {
                try
                {
                    await _rentalService.PayAsync(transaction.RentalId.Value, transaction.UserId);
                    message += $" Đơn #{transaction.RentalId} đã được thanh toán.";
                }
                catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
                {
                    message += $" Chưa trả được đơn #{transaction.RentalId}: {ex.Message} Tiền vẫn nằm trong ví.";
                    await _notificationService.AddAsync(transaction.UserId, NotificationType.Wallet,
                        "Chưa thanh toán được đơn", message);
                    await _unitOfWork.SaveChangesAsync();
                }
            }

            return new VnPayCallbackResult { Success = true, RspCode = "00", Message = message };
        }

        private static string BuildQuery(SortedDictionary<string, string> data) =>
            string.Join("&", data.Select(kv => WebUtility.UrlEncode(kv.Key) + "=" + WebUtility.UrlEncode(kv.Value)));

        private string Sign(string text)
        {
            using var hmac = new HMACSHA512(Encoding.UTF8.GetBytes(_settings.HashSecret!));
            return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(text))).ToLowerInvariant();
        }

        private static VnPayCallbackResult Fail(string code, string message) =>
            new() { Success = false, RspCode = code, Message = message };
    }
}
