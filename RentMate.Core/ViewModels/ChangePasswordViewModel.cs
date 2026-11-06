using System.ComponentModel.DataAnnotations;

namespace RentMate.Core.ViewModels
{
    public class ChangePasswordViewModel
    {
        [Required(ErrorMessage = "Vui lòng nhập mật khẩu hiện tại.")]
        [DataType(DataType.Password)]
        public string OldPassword { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu mới.")]
        [MinLength(6, ErrorMessage = "Mật khẩu mới phải có ít nhất 6 ký tự.")]
        [DataType(DataType.Password)]
        public string NewPassword { get; set; } = string.Empty;

        [Required(ErrorMessage = "Vui lòng xác nhận mật khẩu mới.")]
        [Compare(nameof(NewPassword), ErrorMessage = "Xác nhận mật khẩu không khớp.")]
        [DataType(DataType.Password)]
        public string ConfirmPassword { get; set; } = string.Empty;
    }
}
