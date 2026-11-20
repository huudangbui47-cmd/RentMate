namespace RentMate.Core.ViewModels
{
    // Một dòng trên trang "Cài đặt hệ thống"
    public class SystemSettingViewModel
    {
        public string Key { get; set; } = string.Empty;

        public string Group { get; set; } = string.Empty;

        public string Label { get; set; } = string.Empty;

        public string? Description { get; set; }

        // đ, %, ngày, giờ, ảnh...
        public string? Unit { get; set; }

        public bool IsNumber { get; set; }

        public decimal? Min { get; set; }

        public decimal? Max { get; set; }

        public string Value { get; set; } = string.Empty;

        public string DefaultValue { get; set; } = string.Empty;

        // Chưa ai sửa, đang dùng giá trị mặc định
        public bool IsDefault { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
