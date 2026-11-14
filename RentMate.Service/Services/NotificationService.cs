using System.Globalization;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Service.DTOs.Notifications;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class NotificationService : INotificationService
    {
        // App chỉ hiện các thông báo gần nhất
        private const int MaxItems = 50;

        private static readonly CultureInfo Vietnamese = new("vi-VN");

        private readonly IUnitOfWork _unitOfWork;

        public NotificationService(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork;
        }

        // 500000 -> "500.000 đ" (dùng khi soạn nội dung thông báo)
        public static string Money(decimal amount) => $"{Math.Abs(amount).ToString("N0", Vietnamese)} đ";

        public async Task AddAsync(string userId, NotificationType type, string title, string message)
        {
            await _unitOfWork.Notifications.AddAsync(new Notification
            {
                UserId = userId,
                Type = type,
                Title = title,
                Message = message,
                CreatedAt = DateTime.UtcNow
            });
        }

        public async Task<List<NotificationDto>> GetMineAsync(string userId)
        {
            return await _unitOfWork.Notifications
                .BuildQuery(n => n.UserId == userId)
                .OrderByDescending(n => n.CreatedAt)
                .Take(MaxItems)
                .Select(n => new NotificationDto
                {
                    NotificationId = n.Id,
                    Title = n.Title,
                    Message = n.Message,
                    Type = n.Type.ToString(),
                    IsRead = n.IsRead,
                    CreatedAt = n.CreatedAt
                })
                .ToListAsync();
        }

        public async Task<int> GetUnreadCountAsync(string userId)
        {
            return await _unitOfWork.Notifications
                .BuildQuery(n => n.UserId == userId && !n.IsRead)
                .CountAsync();
        }

        public async Task<bool> MarkReadAsync(int notificationId, string userId)
        {
            var notification = await _unitOfWork.Notifications.GetByIdAsync(notificationId);

            if (notification == null || notification.UserId != userId)
                return false;

            notification.IsRead = true;

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        public async Task MarkAllReadAsync(string userId)
        {
            var unreadIds = await _unitOfWork.Notifications
                .BuildQuery(n => n.UserId == userId && !n.IsRead)
                .Select(n => n.Id)
                .ToListAsync();

            // GetByIdsAsync có tracking nên sửa xong lưu được
            foreach (var notification in await _unitOfWork.Notifications.GetByIdsAsync(unreadIds))
                notification.IsRead = true;

            await _unitOfWork.SaveChangesAsync();
        }
    }
}
