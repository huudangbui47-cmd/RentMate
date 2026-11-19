namespace RentMate.Core.Enums
{
    public enum RentalStatus
    {
        Pending = 1,
        Approved = 2,
        Rejected = 3,
        Cancelled = 4,
        WaitingForPickup = 5,
        Rented = 6,
        Returned = 7,
        Completed = 8,
        Overdue = 9,
        DamageClaimed = 10, // Chủ đồ đề nghị trừ cọc, chờ người thuê đồng ý hoặc khiếu nại
        Disputed = 11,      // Người thuê khiếu nại, chờ quản trị viên phân xử
    }
}