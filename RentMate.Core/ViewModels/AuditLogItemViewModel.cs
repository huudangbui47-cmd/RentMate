namespace RentMate.Core.ViewModels
{
    public class AuditLogItemViewModel
    {
        public int Id { get; set; }
        public string UserName { get; set; } = string.Empty;
        public string Action { get; set; } = string.Empty;
        public string EntityName { get; set; } = string.Empty;
        public string? EntityId { get; set; }
        public string? Description { get; set; }
        public string IpAddress { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }

        public string ActionText => Action switch
        {
            "LoginSuccess" => "Đăng nhập thành công",
            "LoginFailed" => "Đăng nhập thất bại",
            "LockUser" => "Khóa tài khoản",
            "UnlockUser" => "Mở khóa tài khoản",
            "RoleChanged" => "Thay đổi vai trò",
            "UpdateProfile" => "Cập nhật hồ sơ",
            "UpdateAvatar" => "Cập nhật ảnh đại diện",
            "ChangePassword" => "Đổi mật khẩu",
            "CreateUser" => "Thêm tài khoản quản lý",
            "UpdateUser" => "Cập nhật tài khoản quản lý",
            "DeleteUser" => "Xóa tài khoản quản lý",
            "CreateCustomer" => "Thêm khách hàng",
            "UpdateCustomer" => "Cập nhật khách hàng",
            "ResetPassword" => "Đặt lại mật khẩu",
            "RequestPasswordReset" => "Yêu cầu đặt lại mật khẩu",
            "ResetPasswordByEmail" => "Đặt lại mật khẩu qua email",
            "CreateCategory" => "Thêm danh mục",
            "UpdateCategory" => "Cập nhật danh mục",
            "ToggleCategory" => "Đổi trạng thái danh mục",
            "DeleteCategory" => "Xóa danh mục",
            "UpdateItemStatus" => "Cập nhật trạng thái đồ",
            "ApproveItem" => "Duyệt đồ",
            "RejectItem" => "Từ chối đồ",
            "ApproveDeposit" => "Duyệt nạp tiền",
            "CompleteWithdraw" => "Xác nhận rút tiền",
            "RejectWalletRequest" => "Từ chối nạp/rút",
            "CustomerUpdateProfile" => "Khách sửa thông tin",
            "CustomerChangePassword" => "Khách đổi mật khẩu",
            "CustomerRequestPasswordReset" => "Khách yêu cầu mã quên mật khẩu",
            "CustomerResetPassword" => "Khách đặt lại mật khẩu bằng mã",
            _ => Action
        };

        public string EntityNameText => EntityName switch
        {
            "ApplicationUser" => "Tài khoản",
            "Customer" => "Khách hàng",
            "Category" => "Danh mục",
            "Item" => "Đồ cho thuê",
            "Rental" => "Đơn thuê",
            "Payment" => "Thanh toán",
            "WalletTransaction" => "Ví",
            _ => EntityName
        };
    }
}
