namespace RentMate.Service.DTOs.Notifications
{
    public class NotificationDto
    {
        public int NotificationId { get; set; }

        public string Title { get; set; } = string.Empty;

        public string Message { get; set; } = string.Empty;

        // Tên enum NotificationType, app dựa vào đây để mở đúng màn hình
        public string Type { get; set; } = string.Empty;

        public bool IsRead { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
