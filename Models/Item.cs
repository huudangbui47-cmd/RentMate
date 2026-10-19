using RentMate.Api.Models.Enums;

namespace RentMate.Api.Models
{
    public class Item
    {
        public int ItemId { get; set; }

        public string ItemName { get; set; } = string.Empty;

        public string? Description { get; set; }

        public decimal PricePerDay { get; set; }

        public decimal DepositAmount { get; set; }

        public ItemCondition Condition { get; set; }

        public ItemStatus Status { get; set; } = ItemStatus.Available;

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