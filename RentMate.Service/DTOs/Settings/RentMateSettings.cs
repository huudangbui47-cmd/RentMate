namespace RentMate.Service.DTOs.Settings
{
    // Các cài đặt hệ thống đang áp dụng (đọc từ bảng SystemSettings, thiếu thì lấy mặc định).
    // Service nghiệp vụ lấy qua ISystemSettingService.GetAsync() thay cho hằng số viết cứng.
    public class RentMateSettings
    {
        // Phí & tiền
        public decimal PlatformFeePercent { get; set; } = 5;
        public decimal PlatformFeeRate => PlatformFeePercent / 100m;
        public int MinWalletAmount { get; set; } = 10_000;
        public int MaxWalletAmount { get; set; } = 50_000_000;
        public int MaxPendingDeposits { get; set; } = 3;

        // Đơn thuê
        public int MaxRentalDays { get; set; } = 30;
        public int MaxDaysAhead { get; set; } = 90;
        public int PaymentTimeoutHours { get; set; } = 24;
        public int OwnerInspectionDays { get; set; } = 3;
        public int RenterResponseDays { get; set; } = 2;

        // Đồ & biên bản
        public int MaxItemImages { get; set; } = 8;
        public int MaxReportImages { get; set; } = 6;

        // Tài khoản nhận tiền nạp ví (chuyển khoản thủ công)
        public string? BankId { get; set; }
        public string? BankName { get; set; }
        public string? BankAccountNumber { get; set; }
        public string? BankAccountName { get; set; }

        // Liên hệ hỗ trợ, hiện trong app
        public string? SupportPhone { get; set; }
        public string? SupportEmail { get; set; }
    }
}
