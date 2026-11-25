using RentMate.Core.Enums;

namespace RentMate.Core.Models
{
    public class Rental : BaseEntity
    {
        public DateTime StartDate { get; set; }

        public DateTime EndDate { get; set; }

        public decimal PricePerDay { get; set; }

        public decimal DepositAmount { get; set; }

        public decimal TotalPrice { get; set; }

        // Tỉ lệ phí nền tảng lúc đặt đơn (0.05 = 5%). Admin đổi phí sau đó thì đơn cũ vẫn giữ tỉ lệ cũ.
        public decimal PlatformFeeRate { get; set; } = 0.05m;

        public string? RequestNote { get; set; }

        public RentalStatus Status { get; set; }
            = RentalStatus.Pending;

        public DateTime RequestedAt { get; set; }
            = DateTime.UtcNow;

        public DateTime? ApprovedAt { get; set; }

        public DateTime? ReceivedAt { get; set; }

        public DateTime? ReturnedAt { get; set; }

        public DateTime? CompletedAt { get; set; }

        // Bồi thường hư hỏng: trừ vào tiền cọc, chủ đồ nhận phần này
        public decimal DamageAmount { get; set; }

        public string? DamageNote { get; set; }

        public DateTime? DamageClaimedAt { get; set; }

        // Người thuê khiếu nại mức bồi thường, quản trị viên phân xử
        public string? DisputeReason { get; set; }

        public DateTime? DisputedAt { get; set; }

        public string? ResolutionNote { get; set; }

        // Lý do hủy (vd. người thuê từ chối nhận vì giao sai món)
        public string? CancelReason { get; set; }

        // Giao nhận: gặp trực tiếp hoặc giao qua GHN
        public DeliveryMethod DeliveryMethod { get; set; } = DeliveryMethod.Meetup;

        public string? ShipToName { get; set; }

        public string? ShipToPhone { get; set; }

        // Số nhà, tên đường
        public string? ShipToAddress { get; set; }

        // Mã quận/phường theo danh mục của GHN
        public int? ShipToDistrictId { get; set; }

        public string? ShipToWardCode { get; set; }

        // "Phường X, Quận Y, Tỉnh Z" để hiển thị
        public string? ShipToAreaText { get; set; }

        public string? ShippingOrderCode { get; set; }

        public decimal? ShippingFee { get; set; }

        public DateTime? ShippingCreatedAt { get; set; }

        public DateTime? ExpectedDeliveryAt { get; set; }

        // Đồ đến tay trễ hơn ngày bắt đầu: số ngày đã lùi hạn trả,
        // hoặc tiền thuê hoàn lại khi không lùi được (vướng lịch người thuê sau)
        public int ShiftedDays { get; set; }

        public decimal LateDeliveryRefund { get; set; }

        // Ưu đãi thuê dài ngày áp dụng lúc đặt đơn (giữ lại để tính hoàn tiền), TotalPrice đã trừ DiscountAmount
        public int DiscountPercent { get; set; }

        public decimal DiscountAmount { get; set; }

        // Foreign Keys
        public int ItemId { get; set; }

        public string RenterId { get; set; } = string.Empty;

        // Navigation
        public Item Item { get; set; } = null!;

        public ApplicationUser Renter { get; set; } = null!;

        public ICollection<Payment> Payments { get; set; }
            = new List<Payment>();

        public ICollection<ConditionReport> ConditionReports { get; set; }
            = new List<ConditionReport>();

        public ICollection<Review> Reviews { get; set; }
            = new List<Review>();
    }
}