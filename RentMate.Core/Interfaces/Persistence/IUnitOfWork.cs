using System.Data;
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

        IRepository<SystemSetting> SystemSettings { get; }
        IRepository<AppLanguage> AppLanguages { get; }
        IRepository<TextResource> TextResources { get; }
        IRepository<TextTranslation> TextTranslations { get; }

        Task<int> SaveChangesAsync();

        // Dùng khi một thao tác buộc phải lưu nhiều lần (vd. UserManager.CreateAsync rồi AddToRoleAsync):
        // lỗi ở bước sau thì Rollback để bỏ cả những bước đã lưu trước đó.
        // Thao tác bình thường chỉ cần gom vào một lần SaveChangesAsync (EF tự bọc transaction).
        // Serializable: dùng cho thao tác kiểm tra số dư rồi trừ tiền, để 2 lệnh gửi cùng lúc không cùng qua bước kiểm tra
        Task BeginTransactionAsync(IsolationLevel isolationLevel = IsolationLevel.ReadCommitted);
        Task CommitTransactionAsync();
        Task RollbackTransactionAsync();
    }
}
