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

        public int CategoryId { get; set; }

        public string CategoryName { get; set; } = string.Empty;

        public string OwnerId { get; set; } = string.Empty;

        public string OwnerName { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; }
    }
}