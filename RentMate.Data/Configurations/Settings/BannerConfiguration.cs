using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Settings
{
    public class BannerConfiguration : IEntityTypeConfiguration<Banner>
    {
        public void Configure(EntityTypeBuilder<Banner> builder)
        {
            builder.Property(b => b.Id).HasColumnName("BannerId");
            builder.Property(b => b.ImageUrl).HasMaxLength(300).IsRequired();
            builder.Property(b => b.Title).HasMaxLength(100);
            builder.HasIndex(b => new { b.IsActive, b.SortOrder });
        }
    }
}
