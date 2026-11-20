namespace RentMate.Service.DTOs.Settings
{
    // Cài đặt app cần biết để hiện đúng giới hạn và câu chữ (không gồm thông tin nhạy cảm)
    public class PublicSettingsDto
    {
        public decimal PlatformFeePercent { get; set; }
        public int MinWalletAmount { get; set; }
        public int MaxWalletAmount { get; set; }
        public int MaxRentalDays { get; set; }
        public int MaxDaysAhead { get; set; }
        public int PaymentTimeoutHours { get; set; }
        public int OwnerInspectionDays { get; set; }
        public int RenterResponseDays { get; set; }
        public int MaxItemImages { get; set; }
        public int MaxReportImages { get; set; }
        public string? SupportPhone { get; set; }
        public string? SupportEmail { get; set; }
    }
}
