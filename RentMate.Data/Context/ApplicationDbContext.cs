using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Models;

namespace RentMate.Data.Context
{
    public class ApplicationDbContext : IdentityDbContext<ApplicationUser>
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<Category> Categories { get; set; } = null!;
        public DbSet<Item> Items { get; set; } = null!;
        public DbSet<ItemImage> ItemImages { get; set; } = null!;

        public DbSet<Rental> Rentals { get; set; } = null!;
        public DbSet<Payment> Payments { get; set; } = null!;

        public DbSet<ConditionReport> ConditionReports { get; set; } = null!;
        public DbSet<ConditionReportImage> ConditionReportImages { get; set; } = null!;

        public DbSet<Review> Reviews { get; set; } = null!;
        public DbSet<Notification> Notifications { get; set; } = null!;

        public DbSet<AuditLog> AuditLogs { get; set; } = null!;

        public DbSet<WalletTransaction> WalletTransactions { get; set; } = null!;

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);

            // Mỗi entity có 1 file cấu hình riêng trong thư mục Configurations/
            builder.ApplyConfigurationsFromAssembly(typeof(ApplicationDbContext).Assembly);
        }
    }
}
