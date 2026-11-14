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

        IRepository<WalletTransaction> WalletTransactions { get; }

        Task<int> SaveChangesAsync();

        // Dùng khi một thao tác buộc phải lưu nhiều lần (vd. UserManager.CreateAsync rồi AddToRoleAsync):
        // lỗi ở bước sau thì Rollback để bỏ cả những bước đã lưu trước đó.
        // Thao tác bình thường chỉ cần gom vào một lần SaveChangesAsync (EF tự bọc transaction).
        Task BeginTransactionAsync();
        Task CommitTransactionAsync();
        Task RollbackTransactionAsync();
    }
}
