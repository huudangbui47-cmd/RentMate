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

        // Phí nền tảng của đơn này (theo cài đặt lúc đặt), vd. 5
        public decimal PlatformFeePercent { get; set; }

        public string Status { get; set; } = string.Empty;

        public string? RequestNote { get; set; }

        public DateTime RequestedAt { get; set; }

        // Chủ đồ được hủy đơn đã duyệt nếu người thuê chưa thanh toán sau 24 giờ kể từ lúc này
        public DateTime? ApprovedAt { get; set; }

        public DateTime? ReceivedAt { get; set; }

        public DateTime? ReturnedAt { get; set; }

        public DateTime? CompletedAt { get; set; }

        // Bồi thường / khiếu nại
        public decimal DamageAmount { get; set; }

        public string? DamageNote { get; set; }

        public DateTime? DamageClaimedAt { get; set; }

        public string? DisputeReason { get; set; }

        public string? ResolutionNote { get; set; }

        // Hạn chót để app hiện nút đúng lúc: chủ đồ kiểm tra đồ / người thuê phản hồi bồi thường
        public DateTime? OwnerInspectionDeadline { get; set; }

        public DateTime? RenterResponseDeadline { get; set; }

        public string? CancelReason { get; set; }

        // Giao nhận
        public string DeliveryMethod { get; set; } = "Meetup";

        public string? ShipToName { get; set; }

        public string? ShipToPhone { get; set; }

        public string? ShipToAddress { get; set; }

        public string? ShipToAreaText { get; set; }

        public string? ShippingOrderCode { get; set; }

        public decimal? ShippingFee { get; set; }

        public DateTime? ExpectedDeliveryAt { get; set; }

        public int ShiftedDays { get; set; }

        public decimal LateDeliveryRefund { get; set; }
    }
}