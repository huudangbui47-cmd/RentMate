using System.ComponentModel.DataAnnotations;

namespace RentMate.Service.DTOs.Rentals
{
    // Lý do hủy, không bắt buộc (vd. người thuê từ chối nhận vì đồ khác tin đăng)
    public class CancelRentalDto
    {
        [MaxLength(500)]
        public string? Reason { get; set; }
    }
}
