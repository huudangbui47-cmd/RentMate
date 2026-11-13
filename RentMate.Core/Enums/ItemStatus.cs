namespace RentMate.Core.Enums
{
    public enum ItemStatus
    {
        Available = 1,
        Rented = 2,
        Unavailable = 3,
        Hidden = 4,

        // Khách vừa đăng hoặc vừa sửa: chờ quản lý duyệt mới hiện trên app
        PendingApproval = 5,

        // Quản lý từ chối (lý do lưu ở Item.RejectionReason); khách sửa lại thì được duyệt lại
        Rejected = 6
    }
}
