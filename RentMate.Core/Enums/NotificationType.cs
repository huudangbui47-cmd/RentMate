namespace RentMate.Core.Enums
{
    public enum NotificationType
    {
        RentalRequest = 1,
        RentalApproved = 2,
        RentalRejected = 3,
        Payment = 4,
        ReturnReminder = 5,
        Review = 6,
        System = 7,
        Item = 8,       // Đồ được duyệt / bị từ chối / bị tạm ngưng
        Wallet = 9      // Nạp, rút tiền được xử lý
    }
}