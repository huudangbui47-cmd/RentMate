namespace RentMate.Service.DTOs.Rentals
{
    // Chủ đồ hoàn tất đơn: DamageAmount = 0 là hoàn đủ cọc; lớn hơn 0 thì người thuê phải đồng ý hoặc khiếu nại
    public class CompleteRentalDto
    {
        public decimal DamageAmount { get; set; }

        public string? DamageNote { get; set; }
    }
}
