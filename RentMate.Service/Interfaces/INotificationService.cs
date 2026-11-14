using RentMate.Core.Enums;
using RentMate.Service.DTOs.Notifications;

namespace RentMate.Service.Interfaces
{
    public interface INotificationService
    {
        // Chỉ thêm vào UnitOfWork, hàm gọi tự SaveChanges cùng thay đổi chính
        Task AddAsync(string userId, NotificationType type, string title, string message);

        Task<List<NotificationDto>> GetMineAsync(string userId);

        Task<int> GetUnreadCountAsync(string userId);

        Task<bool> MarkReadAsync(int notificationId, string userId);

        Task MarkAllReadAsync(string userId);
    }
}
