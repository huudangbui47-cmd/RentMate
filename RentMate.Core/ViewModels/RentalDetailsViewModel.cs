using RentMate.Core.Enums;

namespace RentMate.Core.ViewModels
{
    public class RentalDetailsViewModel
    {
        public int Id { get; set; }
        public string ItemName { get; set; } = string.Empty;
        public string CategoryName { get; set; } = string.Empty;

        public string RenterName { get; set; } = string.Empty;
        public string? RenterEmail { get; set; }
        public string? RenterPhone { get; set; }

        public string OwnerName { get; set; } = string.Empty;
        public string? OwnerEmail { get; set; }
        public string? OwnerPhone { get; set; }

        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal PricePerDay { get; set; }
        public decimal DepositAmount { get; set; }
        public decimal TotalPrice { get; set; }
        public string? RequestNote { get; set; }
        public RentalStatus Status { get; set; }

        public DateTime RequestedAt { get; set; }
        public DateTime? ApprovedAt { get; set; }
        public DateTime? ReceivedAt { get; set; }
        public DateTime? ReturnedAt { get; set; }
        public DateTime? CompletedAt { get; set; }

        public List<PaymentViewModel> Payments { get; set; } = new();
        public List<ConditionReportViewModel> ConditionReports { get; set; } = new();

        public int NumberOfDays => (EndDate.Date - StartDate.Date).Days + 1;

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
