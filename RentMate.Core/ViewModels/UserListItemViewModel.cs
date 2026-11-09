namespace RentMate.Core.ViewModels
{
    public class UserListItemViewModel
    {
        public string Id { get; set; } = string.Empty;
        public string? ConcurrencyStamp { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }
        public string? AvatarUrl { get; set; }
        public string RoleName { get; set; } = string.Empty;
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }

        public string RoleDisplayName => RoleName switch
        {
            "Admin" => "Quản trị viên",
            "Manager" => "Quản lý",
            "User" => "Khách hàng",
            _ => RoleName
        };
    }
}
