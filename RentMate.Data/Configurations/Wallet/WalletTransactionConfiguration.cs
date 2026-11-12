using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Wallet
{
    public class WalletTransactionConfiguration : IEntityTypeConfiguration<WalletTransaction>
    {
        public void Configure(EntityTypeBuilder<WalletTransaction> builder)
        {
            builder.Property(w => w.Id).HasColumnName("WalletTransactionId");

            builder.Property(w => w.Amount).HasPrecision(18, 2);

            builder.Property(w => w.Code).HasMaxLength(20);

            builder.Property(w => w.Note).HasMaxLength(500);

            builder.Property(w => w.RowVersion).IsRowVersion();

            // Mỗi mã nạp là duy nhất, để webhook/admin tìm đúng một giao dịch.
            builder.HasIndex(w => w.Code)
                .IsUnique()
                .HasFilter("[Code] IS NOT NULL");

            builder.HasIndex(w => new { w.UserId, w.Status });

            // User 1 - N WalletTransaction
            builder.HasOne(w => w.User)
                .WithMany(u => u.WalletTransactions)
                .HasForeignKey(w => w.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            // Rental 1 - N WalletTransaction (không bắt buộc)
            builder.HasOne(w => w.Rental)
                .WithMany()
                .HasForeignKey(w => w.RentalId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
