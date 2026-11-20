using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Settings;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    // Cài đặt hệ thống: quản trị viên sửa trên trang "Cài đặt", nghiệp vụ đọc qua GetAsync().
    // Danh sách cài đặt, giới hạn hợp lệ và giá trị mặc định khai báo ở Definitions bên dưới;
    // database chỉ lưu những giá trị đã được sửa.
    public class SystemSettingService : ISystemSettingService
    {
        private const string CacheKey = "RentMateSettings";

        // Api và AdminSite là 2 tiến trình riêng: sửa ở AdminSite thì Api thấy giá trị mới sau tối đa ngần này
        private static readonly TimeSpan CacheDuration = TimeSpan.FromSeconds(30);

        private const string GroupMoney = "Phí và tiền";
        private const string GroupRental = "Đơn thuê";
        private const string GroupItem = "Đồ và biên bản";
        private const string GroupBank = "Tài khoản nhận tiền nạp ví";
        private const string GroupSupport = "Liên hệ hỗ trợ";

        private sealed record Definition(
            string Key,
            string Group,
            string Label,
            string? Description,
            string? Unit,
            decimal? Min,
            decimal? Max,
            string Default,
            Action<RentMateSettings, string> Apply,
            int MaxLength = 100)
        {
            public bool IsNumber => Min != null;
        }

        private static readonly List<Definition> Definitions = new()
        {
            new("Fee.PlatformPercent", GroupMoney, "Phí nền tảng",
                "Phần trăm RentMate giữ lại trên tiền thuê khi đơn hoàn tất. Chỉ áp dụng cho đơn đặt sau khi đổi, đơn cũ giữ mức phí lúc đặt.",
                "%", 0, 30, "5", (s, v) => s.PlatformFeePercent = Dec(v)),
            new("Wallet.MinAmount", GroupMoney, "Số tiền nạp / rút tối thiểu", null,
                "đ", 1_000, 10_000_000, "10000", (s, v) => s.MinWalletAmount = Int(v)),
            new("Wallet.MaxAmount", GroupMoney, "Số tiền nạp / rút tối đa mỗi lần", null,
                "đ", 100_000, 500_000_000, "50000000", (s, v) => s.MaxWalletAmount = Int(v)),
            new("Wallet.MaxPendingDeposits", GroupMoney, "Số yêu cầu nạp chuyển khoản được chờ cùng lúc",
                "Chống tạo hàng loạt yêu cầu nạp rồi bỏ đó. Nạp qua VNPay không tính.",
                "yêu cầu", 1, 20, "3", (s, v) => s.MaxPendingDeposits = Int(v)),

            new("Rental.MaxDays", GroupRental, "Số ngày thuê tối đa mỗi đơn", null,
                "ngày", 1, 365, "30", (s, v) => s.MaxRentalDays = Int(v)),
            new("Rental.MaxDaysAhead", GroupRental, "Đặt thuê trước tối đa", null,
                "ngày", 1, 365, "90", (s, v) => s.MaxDaysAhead = Int(v)),
            new("Rental.PaymentTimeoutHours", GroupRental, "Hạn thanh toán sau khi chủ đồ duyệt",
                "Quá hạn mà người thuê chưa thanh toán thì chủ đồ được hủy đơn.",
                "giờ", 1, 168, "24", (s, v) => s.PaymentTimeoutHours = Int(v)),
            new("Rental.OwnerInspectionDays", GroupRental, "Thời gian chủ đồ kiểm tra đồ trả lại",
                "Quá hạn mà chủ đồ chưa hoàn tất thì người thuê được tự hoàn tất và nhận đủ cọc.",
                "ngày", 1, 14, "3", (s, v) => s.OwnerInspectionDays = Int(v)),
            new("Rental.RenterResponseDays", GroupRental, "Thời gian người thuê phản hồi yêu cầu bồi thường",
                "Quá hạn mà người thuê không đồng ý hay khiếu nại thì chủ đồ được chốt mức đã đề nghị.",
                "ngày", 1, 14, "2", (s, v) => s.RenterResponseDays = Int(v)),

            new("Item.MaxImages", GroupItem, "Số ảnh tối đa mỗi món đồ", null,
                "ảnh", 1, 20, "8", (s, v) => s.MaxItemImages = Int(v)),
            new("Report.MaxImages", GroupItem, "Số ảnh tối đa mỗi biên bản", null,
                "ảnh", 1, 12, "6", (s, v) => s.MaxReportImages = Int(v)),

            new("Bank.BankId", GroupBank, "Mã ngân hàng VietQR",
                "Mã BIN hoặc tên viết tắt theo VietQR (vd. 970436 hoặc VCB), dùng để tạo mã QR chuyển khoản. Để trống thì app chỉ hiện thông tin chuyển khoản, không có mã QR.",
                null, null, null, "", (s, v) => s.BankId = Text(v), 20),
            new("Bank.BankName", GroupBank, "Tên ngân hàng", null,
                null, null, null, "", (s, v) => s.BankName = Text(v)),
            new("Bank.AccountNumber", GroupBank, "Số tài khoản", null,
                null, null, null, "", (s, v) => s.BankAccountNumber = Text(v), 30),
            new("Bank.AccountName", GroupBank, "Chủ tài khoản", null,
                null, null, null, "", (s, v) => s.BankAccountName = Text(v)),

            new("Support.Phone", GroupSupport, "Số điện thoại hỗ trợ", "Hiện trong mục Tài khoản của app.",
                null, null, null, "", (s, v) => s.SupportPhone = Text(v), 20),
            new("Support.Email", GroupSupport, "Email hỗ trợ", "Hiện trong mục Tài khoản của app.",
                null, null, null, "", (s, v) => s.SupportEmail = Text(v)),
        };

        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuditLogService _auditLogService;
        private readonly IMemoryCache _cache;

        public SystemSettingService(IUnitOfWork unitOfWork, IAuditLogService auditLogService, IMemoryCache cache)
        {
            _unitOfWork = unitOfWork;
            _auditLogService = auditLogService;
            _cache = cache;
        }

        // =========================
        // NGHIỆP VỤ / API
        // =========================

        public async Task<RentMateSettings> GetAsync()
        {
            if (_cache.TryGetValue(CacheKey, out RentMateSettings? cached) && cached != null)
                return cached;

            var stored = await LoadStoredAsync();
            var settings = new RentMateSettings();

            foreach (var definition in Definitions)
            {
                string value = stored.TryGetValue(definition.Key, out var row) && IsValid(definition, row.Value)
                    ? row.Value
                    : definition.Default;

                definition.Apply(settings, value);
            }

            _cache.Set(CacheKey, settings, CacheDuration);

            return settings;
        }

        public async Task<PublicSettingsDto> GetPublicAsync()
        {
            var s = await GetAsync();

            return new PublicSettingsDto
            {
                PlatformFeePercent = s.PlatformFeePercent,
                MinWalletAmount = s.MinWalletAmount,
                MaxWalletAmount = s.MaxWalletAmount,
                MaxRentalDays = s.MaxRentalDays,
                MaxDaysAhead = s.MaxDaysAhead,
                PaymentTimeoutHours = s.PaymentTimeoutHours,
                OwnerInspectionDays = s.OwnerInspectionDays,
                RenterResponseDays = s.RenterResponseDays,
                MaxItemImages = s.MaxItemImages,
                MaxReportImages = s.MaxReportImages,
                SupportPhone = s.SupportPhone,
                SupportEmail = s.SupportEmail
            };
        }

        // =========================
        // TRANG QUẢN TRỊ
        // =========================

        public async Task<List<SystemSettingViewModel>> GetAllForManagementAsync()
        {
            var stored = await LoadStoredAsync();

            return Definitions.Select(d =>
            {
                stored.TryGetValue(d.Key, out var row);

                return new SystemSettingViewModel
                {
                    Key = d.Key,
                    Group = d.Group,
                    Label = d.Label,
                    Description = d.Description,
                    Unit = d.Unit,
                    IsNumber = d.IsNumber,
                    Min = d.Min,
                    Max = d.Max,
                    Value = row?.Value ?? d.Default,
                    DefaultValue = d.Default,
                    IsDefault = row == null,
                    UpdatedAt = row?.UpdatedAt
                };
            }).ToList();
        }

        // Lưu cả trang một lần; chỉ ghi những cài đặt có thay đổi, gộp vào một dòng nhật ký
        public async Task UpdateAsync(Dictionary<string, string?> values, string actorUserId, string ipAddress)
        {
            var rows = await _unitOfWork.SystemSettings
                .BuildQuery(s => true)
                .ToListAsync();

            // BuildQuery là AsNoTracking: lấy lại bằng id để sửa được
            var tracked = (await _unitOfWork.SystemSettings.GetByIdsAsync(rows.Select(r => r.Id)))
                .ToDictionary(r => r.Key);

            var changes = new List<string>();
            var settings = new RentMateSettings();

            foreach (var definition in Definitions)
            {
                tracked.TryGetValue(definition.Key, out var row);
                string current = row?.Value ?? definition.Default;

                if (!values.TryGetValue(definition.Key, out var input))
                {
                    definition.Apply(settings, current);
                    continue;
                }

                string value = Normalize(definition, input);

                if (!IsValid(definition, value))
                {
                    throw new InvalidOperationException(definition.IsNumber
                        ? $"{definition.Label}: phải là số từ {Show(definition.Min!.Value)} đến {Show(definition.Max!.Value)}."
                        : $"{definition.Label}: tối đa {definition.MaxLength} ký tự.");
                }

                definition.Apply(settings, value);

                if (value == current)
                    continue;

                changes.Add($"{definition.Label}: {Display(current)} → {Display(value)}");

                if (row == null)
                {
                    await _unitOfWork.SystemSettings.AddAsync(new SystemSetting
                    {
                        Key = definition.Key,
                        Value = value,
                        UpdatedAt = DateTime.UtcNow,
                        UpdatedByUserId = actorUserId
                    });
                }
                else
                {
                    row.Value = value;
                    row.UpdatedAt = DateTime.UtcNow;
                    row.UpdatedByUserId = actorUserId;
                }
            }

            if (settings.MinWalletAmount > settings.MaxWalletAmount)
                throw new InvalidOperationException("Số tiền nạp / rút tối thiểu phải nhỏ hơn mức tối đa.");

            if (changes.Count == 0)
                return;

            await _auditLogService.RecordAsync(
                "UpdateSettings",
                "SystemSetting",
                null,
                Cut("Cập nhật cài đặt hệ thống. " + string.Join("; ", changes), 1000),
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();

            _cache.Remove(CacheKey);
        }

        // =========================
        // HỖ TRỢ
        // =========================

        private async Task<Dictionary<string, SystemSetting>> LoadStoredAsync()
        {
            var rows = await _unitOfWork.SystemSettings
                .BuildQuery(s => true)
                .ToListAsync();

            return rows.ToDictionary(r => r.Key);
        }

        // Số: bỏ dấu chấm/phẩy phân cách hàng nghìn admin có thể gõ ("50.000" → "50000"); chữ: cắt khoảng trắng
        private static string Normalize(Definition definition, string? input)
        {
            string value = (input ?? string.Empty).Trim();

            if (!definition.IsNumber)
                return value;

            // Phí % cho phép số lẻ dạng 2,5 hoặc 2.5; các số khác là số nguyên
            if (definition.Unit == "%")
                return value.Replace(',', '.');

            return value.Replace(".", "").Replace(",", "").Replace(" ", "");
        }

        private static bool IsValid(Definition definition, string value)
        {
            if (!definition.IsNumber)
                return value.Length <= definition.MaxLength;

            if (!decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var number))
                return false;

            if (definition.Unit != "%" && number != Math.Floor(number))
                return false;

            return number >= definition.Min && number <= definition.Max;
        }

        private static int Int(string value) => int.Parse(value, CultureInfo.InvariantCulture);

        private static decimal Dec(string value) => decimal.Parse(value, CultureInfo.InvariantCulture);

        private static string? Text(string value) => string.IsNullOrWhiteSpace(value) ? null : value;

        private static string Show(decimal value) => value.ToString("#,0.##", CultureInfo.GetCultureInfo("vi-VN"));

        private static string Display(string value) => string.IsNullOrEmpty(value) ? "(trống)" : value;

        private static string Cut(string text, int max) => text.Length <= max ? text : text[..(max - 1)] + "…";
    }
}
