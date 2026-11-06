using RentMate.Core.Enums;

namespace RentMate.Core.ViewModels
{
    public class ItemListItemViewModel
    {
        public int Id { get; set; }
        public string ItemName { get; set; } = string.Empty;
        public string? ImageUrl { get; set; }
        public string CategoryName { get; set; } = string.Empty;
        public string OwnerName { get; set; } = string.Empty;
        public string? OwnerEmail { get; set; }
        public decimal PricePerDay { get; set; }
        public decimal DepositAmount { get; set; }
        public ItemCondition Condition { get; set; }
        public ItemStatus Status { get; set; }
        public int RentalCount { get; set; }
        public DateTime CreatedAt { get; set; }

        public string StatusText => Status switch
        {
            ItemStatus.Available => "Sẵn sàng",
            ItemStatus.Rented => "Đang cho thuê",
            ItemStatus.Unavailable => "Tạm ngưng",
            ItemStatus.Hidden => "Đã ẩn",
            _ => "Không xác định"
        };

        public string ConditionText => Condition switch
        {
            ItemCondition.New => "Mới",
            ItemCondition.LikeNew => "Như mới",
            ItemCondition.Good => "Tốt",
            ItemCondition.Fair => "Khá",
            ItemCondition.Damaged => "Hư hỏng",
            _ => "Không xác định"
        };
    }
}
