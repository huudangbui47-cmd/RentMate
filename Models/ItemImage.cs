namespace RentMate.Api.Models
{
    public class ItemImage
    {
        public int ItemImageId { get; set; }

        public string ImageUrl { get; set; } = string.Empty;

        public bool IsPrimary { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Foreign Key
        public int ItemId { get; set; }

        // Navigation
        public Item Item { get; set; } = null!;
    }
}