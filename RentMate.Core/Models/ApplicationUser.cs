using Microsoft.AspNetCore.Identity;

namespace RentMate.Core.Models
{
    public class ApplicationUser : IdentityUser
    {
        public string FullName { get; set; } = string.Empty;

        public string? AvatarUrl { get; set; }

        public string? Address { get; set; }

        public bool IsActive { get; set; } = true;

        public DateTime CreatedAt { get; set; }
            = DateTime.UtcNow;

        public ICollection<Item> Items { get; set; }
            = new List<Item>();

        public ICollection<Rental> Rentals { get; set; }
            = new List<Rental>();

        public ICollection<Review> WrittenReviews { get; set; }
            = new List<Review>();

        public ICollection<Review> ReceivedReviews { get; set; }
            = new List<Review>();

        public ICollection<ConditionReport> ConditionReports { get; set; }
            = new List<ConditionReport>();

        public ICollection<Notification> Notifications { get; set; }
            = new List<Notification>();
    }
}