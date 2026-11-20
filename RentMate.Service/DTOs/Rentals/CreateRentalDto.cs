using System.ComponentModel.DataAnnotations;
using RentMate.Core.Enums;

namespace RentMate.Service.DTOs.Rentals
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

        // Giao nhận: 1 gặp trực tiếp, 2 giao qua GHN (cần địa chỉ bên dưới)
        public DeliveryMethod DeliveryMethod { get; set; } = DeliveryMethod.Meetup;

        public string? ShipToName { get; set; }

        public string? ShipToPhone { get; set; }

        public string? ShipToAddress { get; set; }

        public int? ShipToDistrictId { get; set; }

        public string? ShipToWardCode { get; set; }

        public string? ShipToAreaText { get; set; }
    }
}