using System.ComponentModel.DataAnnotations;

namespace RentMate.Service.DTOs.Rentals
{
    public class DisputeRentalDto
    {
        [Required(ErrorMessage = "Vui lòng nhập lý do khiếu nại.")]
        [MaxLength(1000)]
        public string Reason { get; set; } = string.Empty;
    }
}
