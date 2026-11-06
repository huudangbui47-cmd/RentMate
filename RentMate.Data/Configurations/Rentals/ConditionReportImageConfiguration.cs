using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Rentals
{
    public class ConditionReportImageConfiguration : IEntityTypeConfiguration<ConditionReportImage>
    {
        public void Configure(EntityTypeBuilder<ConditionReportImage> builder)
        {
            builder.Property(i => i.Id).HasColumnName("ConditionReportImageId");

            // ConditionReport 1 - N ConditionReportImage
            builder.HasOne(i => i.ConditionReport)
                .WithMany(c => c.Images)
                .HasForeignKey(i => i.ConditionReportId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
