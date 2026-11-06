using RentMate.Core.Models;

namespace RentMate.Core.Interfaces.Persistence
{
    public interface IUnitOfWork
    {
        IRepository<Category> Categories { get; }
        IRepository<Item> Items { get; }
        IRepository<ItemImage> ItemImages { get; }

        IRepository<Rental> Rentals { get; }
        IRepository<Payment> Payments { get; }
        IRepository<ConditionReport> ConditionReports { get; }
        IRepository<ConditionReportImage> ConditionReportImages { get; }
        IRepository<Review> Reviews { get; }

        IRepository<Notification> Notifications { get; }
        IRepository<AuditLog> AuditLogs { get; }

        Task<int> SaveChangesAsync();
    }
}
