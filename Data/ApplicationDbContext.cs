using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using RentMate.Api.Models;

namespace RentMate.Api.Data
{
    public class ApplicationDbContext
        : IdentityDbContext<ApplicationUser>
    {
        public ApplicationDbContext(
            DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<Category> Categories { get; set; }
        public DbSet<Item> Items { get; set; }
        public DbSet<ItemImage> ItemImages { get; set; }

        public DbSet<Rental> Rentals { get; set; }
        public DbSet<Payment> Payments { get; set; }

        public DbSet<ConditionReport> ConditionReports { get; set; }
        public DbSet<ConditionReportImage> ConditionReportImages { get; set; }

        public DbSet<Review> Reviews { get; set; }
        public DbSet<Notification> Notifications { get; set; }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);

            // User 1 - N Item
            builder.Entity<Item>()
                .HasOne(i => i.Owner)
                .WithMany(u => u.Items)
                .HasForeignKey(i => i.OwnerId)
                .OnDelete(DeleteBehavior.Restrict);

            // Category 1 - N Item
            builder.Entity<Item>()
                .HasOne(i => i.Category)
                .WithMany(c => c.Items)
                .HasForeignKey(i => i.CategoryId)
                .OnDelete(DeleteBehavior.Restrict);

            // Item 1 - N ItemImage
            builder.Entity<ItemImage>()
                .HasOne(i => i.Item)
                .WithMany(i => i.Images)
                .HasForeignKey(i => i.ItemId)
                .OnDelete(DeleteBehavior.Cascade);

            // User 1 - N Rental
            builder.Entity<Rental>()
                .HasOne(r => r.Renter)
                .WithMany(u => u.Rentals)
                .HasForeignKey(r => r.RenterId)
                .OnDelete(DeleteBehavior.Restrict);

            // Item 1 - N Rental
            builder.Entity<Rental>()
                .HasOne(r => r.Item)
                .WithMany(i => i.Rentals)
                .HasForeignKey(r => r.ItemId)
                .OnDelete(DeleteBehavior.Restrict);

            // Rental 1 - N Payment
            builder.Entity<Payment>()
                .HasOne(p => p.Rental)
                .WithMany(r => r.Payments)
                .HasForeignKey(p => p.RentalId)
                .OnDelete(DeleteBehavior.Cascade);

            // Rental 1 - N ConditionReport
            builder.Entity<ConditionReport>()
                .HasOne(c => c.Rental)
                .WithMany(r => r.ConditionReports)
                .HasForeignKey(c => c.RentalId)
                .OnDelete(DeleteBehavior.Cascade);

            // User 1 - N ConditionReport
            builder.Entity<ConditionReport>()
                .HasOne(c => c.CreatedByUser)
                .WithMany(u => u.ConditionReports)
                .HasForeignKey(c => c.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            // ConditionReport 1 - N ConditionReportImage
            builder.Entity<ConditionReportImage>()
                .HasOne(i => i.ConditionReport)
                .WithMany(c => c.Images)
                .HasForeignKey(i => i.ConditionReportId)
                .OnDelete(DeleteBehavior.Cascade);

            // Rental 1 - N Review
            builder.Entity<Review>()
                .HasOne(r => r.Rental)
                .WithMany(r => r.Reviews)
                .HasForeignKey(r => r.RentalId)
                .OnDelete(DeleteBehavior.Cascade);

            // User 1 - N Review: người viết
            builder.Entity<Review>()
                .HasOne(r => r.Reviewer)
                .WithMany(u => u.WrittenReviews)
                .HasForeignKey(r => r.ReviewerId)
                .OnDelete(DeleteBehavior.Restrict);

            // User 1 - N Review: người nhận
            builder.Entity<Review>()
                .HasOne(r => r.ReviewedUser)
                .WithMany(u => u.ReceivedReviews)
                .HasForeignKey(r => r.ReviewedUserId)
                .OnDelete(DeleteBehavior.Restrict);

            // User 1 - N Notification
            builder.Entity<Notification>()
                .HasOne(n => n.User)
                .WithMany(u => u.Notifications)
                .HasForeignKey(n => n.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            // Decimal
            builder.Entity<Item>()
                .Property(i => i.PricePerDay)
                .HasPrecision(18, 2);

            builder.Entity<Item>()
                .Property(i => i.DepositAmount)
                .HasPrecision(18, 2);

            builder.Entity<Rental>()
                .Property(r => r.PricePerDay)
                .HasPrecision(18, 2);

            builder.Entity<Rental>()
                .Property(r => r.DepositAmount)
                .HasPrecision(18, 2);

            builder.Entity<Rental>()
                .Property(r => r.TotalPrice)
                .HasPrecision(18, 2);

            builder.Entity<Payment>()
                .Property(p => p.Amount)
                .HasPrecision(18, 2);
        }
    }
}