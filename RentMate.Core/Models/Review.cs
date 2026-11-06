namespace RentMate.Core.Models
{
    public class Review : BaseEntity
    {
        public int Rating { get; set; }

        public string? Comment { get; set; }

        public DateTime CreatedAt { get; set; }
            = DateTime.UtcNow;

        // Foreign Keys
        public int RentalId { get; set; }

        public string ReviewerId { get; set; } = string.Empty;

        public string ReviewedUserId { get; set; } = string.Empty;

        // Navigation
        public Rental Rental { get; set; } = null!;

        public ApplicationUser Reviewer { get; set; } = null!;

        public ApplicationUser ReviewedUser { get; set; } = null!;
    }
}