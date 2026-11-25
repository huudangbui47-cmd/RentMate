using System.ComponentModel.DataAnnotations;

namespace RentMate.Core.ViewModels
{
    // Một ngôn ngữ trên trang "Ngôn ngữ" (thêm / sửa và thống kê số câu đã dịch)
    public class LanguageViewModel
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập mã ngôn ngữ.")]
        [RegularExpression("^[a-z]{2,3}$", ErrorMessage = "Mã ngôn ngữ gồm 2-3 chữ thường theo ISO 639-1, vd. en, zh, ja, fr, ko.")]
        [Display(Name = "Mã ngôn ngữ")]
        public string Code { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập tên ngôn ngữ.")]
        [StringLength(50, ErrorMessage = "Tên ngôn ngữ tối đa 50 ký tự.")]
        [Display(Name = "Tên hiển thị (viết bằng chính ngôn ngữ đó)")]
        public string Name { get; set; } = string.Empty;

        [StringLength(16)]
        [Display(Name = "Cờ (emoji)")]
        public string? Flag { get; set; }

        [Range(0, 999, ErrorMessage = "Thứ tự từ 0 đến 999.")]
        [Display(Name = "Thứ tự hiển thị")]
        public int SortOrder { get; set; }

        [Display(Name = "Hiện trên app")]
        public bool IsActive { get; set; } = true;

        public int TotalTexts { get; set; }

        public int TranslatedCount { get; set; }

        public int MachineCount { get; set; }

        public int Percent => TotalTexts == 0 ? 0 : (int)Math.Round(TranslatedCount * 100.0 / TotalTexts);

        public string StatusText => IsActive ? "Đang hiện trên app" : "Đang ẩn";

        // "Tiếng Trung"... với ngôn ngữ trong danh sách có sẵn
        public string? VietnameseName => LanguagePresetOption.Find(Code)?.VietnameseName;

        public DateTime UpdatedAt { get; set; }
    }
}
