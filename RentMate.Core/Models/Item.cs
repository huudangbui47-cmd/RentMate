using RentMate.Core.Enums;

namespace RentMate.Core.Models
{
    public class Item : BaseEntity
    {
        public string ItemName { get; set; } = string.Empty;

        public string? Description { get; set; }

        public decimal PricePerDay { get; set; }

        public decimal DepositAmount { get; set; }

        public ItemCondition Condition { get; set; }

        public ItemStatus Status { get; set; } = ItemStatus.PendingApproval;

        // Lý do quản lý từ chối, hiện cho chủ đồ trên app
        public string? RejectionReason { get; set; }

        // Nơi nhận đồ: tỉnh/thành (để khách lọc) và khu vực tự ghi (phường/xã...). Không lưu số nhà.
        // Null với đồ đăng trước khi có tính năng này.
        public string? Province { get; set; }

        public string? Area { get; set; }

        // Ưu đãi thuê dài ngày do chủ đồ đặt: giảm DiscountPercent% tiền thuê khi thuê từ DiscountMinDays ngày.
        // DiscountPercent = 0 là không có ưu đãi.
        public int DiscountPercent { get; set; }

        public int DiscountMinDays { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Foreign Keys
        public string OwnerId { get; set; } = string.Empty;

        public int CategoryId { get; set; }

        // Navigation
        public ApplicationUser Owner { get; set; } = null!;

        public Category Category { get; set; } = null!;

        public ICollection<ItemImage> Images { get; set; }
            = new List<ItemImage>();

        public ICollection<Rental> Rentals { get; set; }
            = new List<Rental>();
    }
}