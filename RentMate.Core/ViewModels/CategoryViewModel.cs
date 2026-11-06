using System.ComponentModel.DataAnnotations;

namespace RentMate.Core.ViewModels
{
    public class CategoryViewModel
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập tên danh mục.")]
        [StringLength(100, ErrorMessage = "Tên danh mục tối đa 100 ký tự.")]
        [Display(Name = "Tên danh mục")]
        public string CategoryName { get; set; } = string.Empty;

        [StringLength(500, ErrorMessage = "Mô tả tối đa 500 ký tự.")]
        [Display(Name = "Mô tả")]
        public string? Description { get; set; }

        [Display(Name = "Đang hoạt động")]
        public bool IsActive { get; set; } = true;

        public int ItemCount { get; set; }
    }
}
