using System.ComponentModel.DataAnnotations;

namespace RentMate.Core.ViewModels
{
    public class CategoryViewModel
    {
        public int Id { get; set; }

        // RowVersion dạng Base64, dùng để phát hiện người khác đã sửa trước
        public string? RowVersion { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập tên danh mục.")]
        [StringLength(100, ErrorMessage = "Tên danh mục tối đa 100 ký tự.")]
        [Display(Name = "Tên danh mục")]
        public string CategoryName { get; set; } = string.Empty;

        [StringLength(500, ErrorMessage = "Mô tả tối đa 500 ký tự.")]
        [Display(Name = "Mô tả")]
        public string? Description { get; set; }

        [Display(Name = "Đang hoạt động")]
        public bool IsActive { get; set; } = true;

        // Để trống là danh mục cha
        [Display(Name = "Thuộc danh mục")]
        public int? ParentCategoryId { get; set; }

        public string? ParentCategoryName { get; set; }

        public int ChildCount { get; set; }

        // Danh mục cha: tính cả đồ trong các danh mục con
        public int ItemCount { get; set; }
    }
}
