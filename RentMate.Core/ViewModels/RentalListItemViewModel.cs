using RentMate.Core.Enums;

namespace RentMate.Core.ViewModels
{
    public class RentalListItemViewModel
    {
        public int Id { get; set; }
        public string ItemName { get; set; } = string.Empty;
        public string RenterName { get; set; } = string.Empty;
        public string OwnerName { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal TotalPrice { get; set; }
        public RentalStatus Status { get; set; }
        public DateTime RequestedAt { get; set; }

        public string StatusText => Status switch
        {
            RentalStatus.Pending => "Chờ duyệt",
            RentalStatus.Approved => "Đã duyệt",
            RentalStatus.Rejected => "Từ chối",
            RentalStatus.Cancelled => "Đã hủy",
            RentalStatus.WaitingForPickup => "Chờ nhận đồ",
            RentalStatus.Rented => "Đang thuê",
            RentalStatus.Returned => "Đã trả đồ",
            RentalStatus.Completed => "Hoàn tất",
            RentalStatus.Overdue => "Quá hạn",
            _ => "Không xác định"
        };
    }
}
