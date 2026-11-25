using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Data.Context;
using RentMate.Data.Repository;

namespace RentMate.Data.UnitOfWork
{
    public class UnitOfWork : IUnitOfWork
    {
        private readonly ApplicationDbContext _context;
        private IDbContextTransaction? _transaction;

        public IRepository<Category> Categories { get; }
        public IRepository<Item> Items { get; }
        public IRepository<ItemImage> ItemImages { get; }

        public IRepository<Rental> Rentals { get; }
        public IRepository<Payment> Payments { get; }
        public IRepository<ConditionReport> ConditionReports { get; }
        public IRepository<ConditionReportImage> ConditionReportImages { get; }
        public IRepository<Review> Reviews { get; }

        public IRepository<Notification> Notifications { get; }
        public IRepository<AuditLog> AuditLogs { get; }

        public IRepository<WalletTransaction> WalletTransactions { get; }

        public IRepository<SystemSetting> SystemSettings { get; }
        public IRepository<AppLanguage> AppLanguages { get; }
        public IRepository<TextResource> TextResources { get; }
        public IRepository<TextTranslation> TextTranslations { get; }

        public UnitOfWork(ApplicationDbContext context)
        {
            _context = context;

            Categories = new Repository<Category>(context);
            Items = new Repository<Item>(context);
            ItemImages = new Repository<ItemImage>(context);

            Rentals = new Repository<Rental>(context);
            Payments = new Repository<Payment>(context);
            ConditionReports = new Repository<ConditionReport>(context);
            ConditionReportImages = new Repository<ConditionReportImage>(context);
            Reviews = new Repository<Review>(context);

            Notifications = new Repository<Notification>(context);
            AuditLogs = new Repository<AuditLog>(context);

            WalletTransactions = new Repository<WalletTransaction>(context);

            SystemSettings = new Repository<SystemSetting>(context);
            AppLanguages = new Repository<AppLanguage>(context);
            TextResources = new Repository<TextResource>(context);
            TextTranslations = new Repository<TextTranslation>(context);
        }

        public async Task<int> SaveChangesAsync()
        {
            return await _context.SaveChangesAsync();
        }

        // UserManager dùng chung DbContext (cùng scope) nên các lần lưu của Identity cũng nằm trong transaction này
        public async Task BeginTransactionAsync(IsolationLevel isolationLevel = IsolationLevel.ReadCommitted)
        {
            if (_transaction != null)
                throw new InvalidOperationException("Đang có một transaction chưa kết thúc.");

            _transaction = await _context.Database.BeginTransactionAsync(isolationLevel);
        }

        public async Task CommitTransactionAsync()
        {
            if (_transaction == null)
                throw new InvalidOperationException("Chưa bắt đầu transaction.");

            await _transaction.CommitAsync();
            await _transaction.DisposeAsync();
            _transaction = null;
        }

        public async Task RollbackTransactionAsync()
        {
            if (_transaction == null)
                return;

            await _transaction.RollbackAsync();
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }
}
