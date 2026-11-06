using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Rentals
{
    public class RentalConfiguration : IEntityTypeConfiguration<Rental>
    {
        public void Configure(EntityTypeBuilder<Rental> builder)
        {
            builder.Property(r => r.Id).HasColumnName("RentalId");

            builder.Property(r => r.PricePerDay).HasPrecision(18, 2);
            builder.Property(r => r.DepositAmount).HasPrecision(18, 2);
            builder.Property(r => r.TotalPrice).HasPrecision(18, 2);

            // User 1 - N Rental
            builder.HasOne(r => r.Renter)
                .WithMany(u => u.Rentals)
                .HasForeignKey(r => r.RenterId)
                .OnDelete(DeleteBehavior.Restrict);

            // Item 1 - N Rental
            builder.HasOne(r => r.Item)
                .WithMany(i => i.Rentals)
                .HasForeignKey(r => r.ItemId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
