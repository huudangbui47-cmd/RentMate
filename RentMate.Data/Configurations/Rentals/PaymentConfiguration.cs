using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Rentals
{
    public class PaymentConfiguration : IEntityTypeConfiguration<Payment>
    {
        public void Configure(EntityTypeBuilder<Payment> builder)
        {
            builder.Property(p => p.Id).HasColumnName("PaymentId");

            builder.Property(p => p.Amount).HasPrecision(18, 2);

            // Rental 1 - N Payment
            builder.HasOne(p => p.Rental)
                .WithMany(r => r.Payments)
                .HasForeignKey(p => p.RentalId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
