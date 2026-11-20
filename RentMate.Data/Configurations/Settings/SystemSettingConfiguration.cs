using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Settings
{
    public class SystemSettingConfiguration : IEntityTypeConfiguration<SystemSetting>
    {
        public void Configure(EntityTypeBuilder<SystemSetting> builder)
        {
            builder.Property(s => s.Id).HasColumnName("SystemSettingId");

            builder.Property(s => s.Key).HasMaxLength(100).IsRequired();
            builder.Property(s => s.Value).HasMaxLength(500).IsRequired();
            builder.Property(s => s.UpdatedByUserId).HasMaxLength(450);

            builder.HasIndex(s => s.Key).IsUnique();
        }
    }
}
