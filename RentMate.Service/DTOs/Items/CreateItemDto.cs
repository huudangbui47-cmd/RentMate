namespace RentMate.Service.DTOs.Items
{
    public class CreateItemDto
    {
        public string ItemName { get; set; } = string.Empty;

        public string? Description { get; set; }

        public decimal PricePerDay { get; set; }

        public decimal DepositAmount { get; set; }

        public int CategoryId { get; set; }

        public int Condition { get; set; }

        // Một trong VietnamProvinces.All
        public string Province { get; set; } = string.Empty;

        // Phường/xã hoặc khu vực, không bắt buộc
        public string? Area { get; set; }
    }
}