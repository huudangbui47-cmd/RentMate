using Microsoft.AspNetCore.Identity;

namespace RentMate.Service.Services
{
    // Thông báo lỗi của Identity bằng tiếng Việt (đăng ký, đổi/đặt lại mật khẩu...).
    // Đăng ký trong Program.cs bằng .AddErrorDescriber<VietnameseIdentityErrorDescriber>().
    public class VietnameseIdentityErrorDescriber : IdentityErrorDescriber
    {
        public override IdentityError PasswordTooShort(int length) =>
            new() { Code = nameof(PasswordTooShort), Description = $"Mật khẩu phải có ít nhất {length} ký tự." };

        public override IdentityError PasswordRequiresNonAlphanumeric() =>
            new() { Code = nameof(PasswordRequiresNonAlphanumeric), Description = "Mật khẩu phải có ít nhất 1 ký tự đặc biệt (ví dụ @, #, !)." };

        public override IdentityError PasswordRequiresDigit() =>
            new() { Code = nameof(PasswordRequiresDigit), Description = "Mật khẩu phải có ít nhất 1 chữ số." };

        public override IdentityError PasswordRequiresLower() =>
            new() { Code = nameof(PasswordRequiresLower), Description = "Mật khẩu phải có ít nhất 1 chữ thường." };

        public override IdentityError PasswordRequiresUpper() =>
            new() { Code = nameof(PasswordRequiresUpper), Description = "Mật khẩu phải có ít nhất 1 chữ hoa." };

        public override IdentityError PasswordMismatch() =>
            new() { Code = nameof(PasswordMismatch), Description = "Mật khẩu hiện tại không đúng." };

        public override IdentityError InvalidToken() =>
            new() { Code = nameof(InvalidToken), Description = "Mã xác nhận không đúng hoặc đã hết hạn." };

        public override IdentityError DuplicateEmail(string email) =>
            new() { Code = nameof(DuplicateEmail), Description = $"Email {email} đã được sử dụng." };

        public override IdentityError DuplicateUserName(string userName) =>
            new() { Code = nameof(DuplicateUserName), Description = $"Email {userName} đã được sử dụng." };

        public override IdentityError InvalidEmail(string? email) =>
            new() { Code = nameof(InvalidEmail), Description = "Email không hợp lệ." };

        public override IdentityError InvalidUserName(string? userName) =>
            new() { Code = nameof(InvalidUserName), Description = "Email không hợp lệ." };
    }
}
