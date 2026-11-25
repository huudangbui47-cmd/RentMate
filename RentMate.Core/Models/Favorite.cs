namespace RentMate.Core.Models
{
    // Món đồ khách bấm tim trên app để xem lại sau. Mỗi khách chỉ lưu một món một lần.
    public class Favorite : BaseEntity
    {
        public string UserId { get; set; } = string.Empty;

        public int ItemId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation
        public ApplicationUser User { get; set; } = null!;

        public Item Item { get; set; } = null!;
    }
}
