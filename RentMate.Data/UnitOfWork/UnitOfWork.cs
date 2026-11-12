using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Data.Context;
using RentMate.Data.Repository;

namespace RentMate.Data.UnitOfWork
{
    public class UnitOfWork : IUnitOfWork
    {
        private readonly ApplicationDbContext _context;

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
        }

        public async Task<int> SaveChangesAsync()
        {
            return await _context.SaveChangesAsync();
        }
    }
}
