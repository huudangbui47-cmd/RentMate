using RentMate.Core.Models;
using RentMate.Core.ViewModels;

namespace RentMate.Service.Interfaces
{
    public interface IAuditLogService
    {
        Task<AuditLogListViewModel> SearchAsync(string? userId, DateTime? fromDate, DateTime? toDate, int page = 1);
        Task<List<AuditLog>> GetRecentAsync();
        Task RecordAsync(string action, string entityName, string? entityId, string? description, string ipAddress, string? userId);
    }
}
