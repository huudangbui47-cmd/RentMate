using System.ComponentModel.DataAnnotations;

namespace RentMate.Core.ViewModels
{
    public class UserEditViewModel : IValidatableObject
    {
        public string Id { get; set; } = string.Empty;

        [Required(ErrorMessage = "Họ tên không được để trống.")]
        [StringLength(100, ErrorMessage = "Họ tên tối đa 100 ký tự.")]
        public string FullName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Email không được để trống.")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
        [StringLength(100, ErrorMessage = "Email tối đa 100 ký tự.")]
        public string Email { get; set; } = string.Empty;

        [RegularExpression(@"^0[0-9]{9}$", ErrorMessage = "Số điện thoại phải gồm 10 chữ số và bắt đầu bằng 0.")]
        public string? PhoneNumber { get; set; }

        [RegularExpression(@"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^a-zA-Z\d]).{6,}$",
            ErrorMessage = "Mật khẩu phải có ít nhất 6 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.")]
        public string? NewPassword { get; set; }

        [Compare(nameof(NewPassword), ErrorMessage = "Mật khẩu xác nhận không khớp.")]
        public string? ConfirmPassword { get; set; }

        public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
        {
            if (!string.IsNullOrWhiteSpace(NewPassword) &&
                string.IsNullOrWhiteSpace(ConfirmPassword))
            {
                yield return new ValidationResult("Vui lòng xác nhận mật khẩu mới.",
                    new[] { nameof(ConfirmPassword) });
            }
            if (string.IsNullOrWhiteSpace(NewPassword) &&
                !string.IsNullOrWhiteSpace(ConfirmPassword))
            {
                yield return new ValidationResult("Hãy nhập mật khẩu mới hoặc để trống cả hai ô mật khẩu.",
                    new[] { nameof(NewPassword) });
            }
        }
    }
}
