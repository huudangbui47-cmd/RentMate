using System.ComponentModel.DataAnnotations;

namespace RentMate.Core.ViewModels
{
    public class CustomerViewModel
    {
        public string Id { get; set; } = string.Empty;

        [Required(ErrorMessage = "Họ tên không được để trống.")]
        [StringLength(100, ErrorMessage = "Họ tên tối đa 100 ký tự.")]
        public string FullName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Email không được để trống.")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
        [StringLength(100, ErrorMessage = "Email tối đa 100 ký tự.")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Số điện thoại không được để trống.")]
        [RegularExpression(@"^0[0-9]{9}$", ErrorMessage = "Số điện thoại phải gồm 10 chữ số và bắt đầu bằng 0.")]
        public string PhoneNumber { get; set; } = string.Empty;

        [StringLength(200, ErrorMessage = "Địa chỉ tối đa 200 ký tự.")]
        public string? Address { get; set; }

        public bool IsActive { get; set; } = true;

        public DateTime CreatedAt { get; set; }

        public int ItemCount { get; set; }

        public int RentalCount { get; set; }
    }
}
