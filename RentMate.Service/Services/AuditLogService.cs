using Microsoft.EntityFrameworkCore;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class AuditLogService : IAuditLogService
    {
        private readonly IUnitOfWork _unitOfWork;

        public AuditLogService(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork;
        }

        public async Task<AuditLogListViewModel> SearchAsync(string? userId, DateTime? fromDate, DateTime? toDate, int page = 1)
        {
            var query = _unitOfWork.AuditLogs
                    .BuildQuery(log => true);

            if (!string.IsNullOrWhiteSpace(userId))
            {
                query = query.Where(log => log.UserId == userId);
            }

            // Ngày lọc theo giờ Việt Nam, dữ liệu lưu UTC
            if (fromDate.HasValue)
            {
                DateTime start = fromDate.Value.Date.ToUniversalTime();

                query = query.Where(log => log.CreatedAt >= start);
            }

            if (toDate.HasValue)
            {
                DateTime end = toDate.Value.Date.AddDays(1).ToUniversalTime();

                query = query.Where(log => log.CreatedAt < end);
            }

            int totalCount = await query.CountAsync();
            const int pageSize = 10;
            page = Math.Clamp(page, 1, Math.Max(1, (totalCount + pageSize - 1) / pageSize));
            var logs = await query
                    .OrderByDescending(log => log.CreatedAt).ThenByDescending(log => log.Id)
                    .Skip((page - 1) * pageSize).Take(pageSize)
                    .Select(log =>
                        new AuditLogItemViewModel
                        {
                            Id = log.Id,

                            UserName = log.User != null ? log.User.FullName : "Không xác định",

                            Action = log.Action,

                            EntityName = log.EntityName,

                            EntityId = log.EntityId,

                            Description = log.Description,

                            IpAddress = log.IpAddress,

                            CreatedAt = log.CreatedAt
                        })
                    .ToListAsync();

            // Chỉ liệt kê những người đã có nhật ký
            var users = await _unitOfWork.AuditLogs
                    .BuildQuery(log => log.UserId != null)
                    .Select(log => new AuditLogUserViewModel
                    {
                        Id = log.UserId!,
                        FullName = log.User!.FullName
                    })
                    .Distinct()
                    .OrderBy(u => u.FullName)
                    .ToListAsync();

            return new AuditLogListViewModel
            {
                UserId = userId,
                FromDate = fromDate,
                ToDate = toDate,
                Logs = logs,
                Page = page, PageSize = pageSize, TotalCount = totalCount,
                Users = users
            };
        }

        public async Task<List<AuditLog>> GetRecentAsync()
        {
            return await _unitOfWork.AuditLogs
                .BuildQuery(log => true)
                .Include(log => log.User)
                .OrderByDescending(log => log.CreatedAt)
                .Take(100)
                .ToListAsync();
        }

        public async Task RecordAsync(string action, string entityName, string? entityId, string? description, string ipAddress, string? userId)
        {
            var log = new AuditLog
            {
                Action = action,
                EntityName = entityName,
                EntityId = entityId,
                Description = description,
                IpAddress = ipAddress,
                UserId = userId,
                CreatedAt = DateTime.UtcNow
            };

            await _unitOfWork.AuditLogs.AddAsync(log);
        }
    }
}
