namespace RentMate.Core.Models
{
    public class ItemImage : BaseEntity
    {
        public string ImageUrl { get; set; } = string.Empty;

        public bool IsPrimary { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Foreign Key
        public int ItemId { get; set; }

        // Navigation
        public Item Item { get; set; } = null!;
    }
}