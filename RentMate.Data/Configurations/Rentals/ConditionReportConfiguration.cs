using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Rentals
{
    public class ConditionReportConfiguration : IEntityTypeConfiguration<ConditionReport>
    {
        public void Configure(EntityTypeBuilder<ConditionReport> builder)
        {
            builder.Property(c => c.Id).HasColumnName("ConditionReportId");

            // Rental 1 - N ConditionReport
            builder.HasOne(c => c.Rental)
                .WithMany(r => r.ConditionReports)
                .HasForeignKey(c => c.RentalId)
                .OnDelete(DeleteBehavior.Cascade);

            // User 1 - N ConditionReport
            builder.HasOne(c => c.CreatedByUser)
                .WithMany(u => u.ConditionReports)
                .HasForeignKey(c => c.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
