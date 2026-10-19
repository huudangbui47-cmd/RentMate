namespace RentMate.Api.DTOs.Items
{
    public class CreateItemDto
    {
        public string ItemName { get; set; } = string.Empty;

        public string? Description { get; set; }

        public decimal PricePerDay { get; set; }

        public decimal DepositAmount { get; set; }

        public int CategoryId { get; set; }

        public int Condition { get; set; }
    }
}