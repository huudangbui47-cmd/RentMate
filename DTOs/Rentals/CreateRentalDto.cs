using System.ComponentModel.DataAnnotations;

namespace RentMate.Api.DTOs.Rentals
{
    public class CreateRentalDto
    {
        [Required]
        public int ItemId { get; set; }

        [Required]
        public DateTime StartDate { get; set; }

        [Required]
        public DateTime EndDate { get; set; }

        public string? RequestNote { get; set; }
    }
}