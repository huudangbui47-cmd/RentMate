namespace RentMate.Service.DTOs.Items
{
    public class ItemDto
    {
        public int ItemId { get; set; }

        public string ItemName { get; set; } = string.Empty;

        public string? Description { get; set; }

        public decimal PricePerDay { get; set; }

        public decimal DepositAmount { get; set; }

        public string Condition { get; set; } = string.Empty;

        public string Status { get; set; } = string.Empty;

        // Chỉ có khi bị từ chối (chủ đồ xem ở "Đồ của tôi")
        public string? RejectionReason { get; set; }

        public int CategoryId { get; set; }

        public string CategoryName { get; set; } = string.Empty;

        public string OwnerId { get; set; } = string.Empty;

        public string OwnerName { get; set; } = string.Empty;

        public string? OwnerAvatarUrl { get; set; }

        public DateTime CreatedAt { get; set; }

        // Ảnh chính để hiện ở danh sách
        public string? ImageUrl { get; set; }

        // Ảnh chính đứng đầu, sau đó theo thứ tự tải lên
        public List<ItemImageDto> Images { get; set; } = new();
    }
}