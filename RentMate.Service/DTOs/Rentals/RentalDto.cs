namespace RentMate.Service.DTOs.Rentals
{
    public class RentalDto
    {
        public int RentalId { get; set; }

        public int ItemId { get; set; }

        public string ItemName { get; set; } = string.Empty;

        public string RenterId { get; set; } = string.Empty;

        public string RenterName { get; set; } = string.Empty;

        public string OwnerId { get; set; } = string.Empty;

        public string OwnerName { get; set; } = string.Empty;

        public DateTime StartDate { get; set; }

        public DateTime EndDate { get; set; }

        public decimal PricePerDay { get; set; }

        public decimal DepositAmount { get; set; }

        public decimal TotalPrice { get; set; }

        public string Status { get; set; } = string.Empty;

        public string? RequestNote { get; set; }

        public DateTime RequestedAt { get; set; }

        // Chủ đồ được hủy đơn đã duyệt nếu người thuê chưa thanh toán sau 24 giờ kể từ lúc này
        public DateTime? ApprovedAt { get; set; }
    }
}