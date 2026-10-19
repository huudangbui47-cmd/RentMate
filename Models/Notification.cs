using RentMate.Api.Models.Enums;

namespace RentMate.Api.Models
{
    public class Notification
    {
        public int NotificationId { get; set; }

        public string Title { get; set; } = string.Empty;

        public string Message { get; set; } = string.Empty;

        public NotificationType Type { get; set; }

        public bool IsRead { get; set; } = false;

        public DateTime CreatedAt { get; set; }
            = DateTime.UtcNow;

        // Foreign Key
        public string UserId { get; set; } = string.Empty;

        // Navigation
        public ApplicationUser User { get; set; } = null!;
    }
}