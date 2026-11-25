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
            builder.Property(r => r.PlatformFeeRate).HasPrecision(5, 4).HasDefaultValue(0.05m);
            builder.Property(r => r.DamageAmount).HasPrecision(18, 2);
            builder.Property(r => r.DamageNote).HasMaxLength(1000);
            builder.Property(r => r.DisputeReason).HasMaxLength(1000);
            builder.Property(r => r.ResolutionNote).HasMaxLength(1000);
            builder.Property(r => r.CancelReason).HasMaxLength(500);
            builder.Property(r => r.ShipToName).HasMaxLength(100);
            builder.Property(r => r.ShipToPhone).HasMaxLength(20);
            builder.Property(r => r.ShipToAddress).HasMaxLength(300);
            builder.Property(r => r.ShipToWardCode).HasMaxLength(20);
            builder.Property(r => r.ShipToAreaText).HasMaxLength(300);
            builder.Property(r => r.ShippingOrderCode).HasMaxLength(50);
            builder.Property(r => r.ShippingFee).HasPrecision(18, 2);
            builder.Property(r => r.LateDeliveryRefund).HasPrecision(18, 2);
            builder.Property(r => r.DiscountAmount).HasPrecision(18, 2);

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
