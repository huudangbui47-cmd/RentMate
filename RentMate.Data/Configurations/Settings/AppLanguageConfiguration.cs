using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Settings
{
    public class AppLanguageConfiguration : IEntityTypeConfiguration<AppLanguage>
    {
        public void Configure(EntityTypeBuilder<AppLanguage> builder)
        {
            builder.Property(l => l.Id).HasColumnName("LanguageId");

            builder.Property(l => l.Code).HasMaxLength(10).IsRequired();
            builder.Property(l => l.Name).HasMaxLength(50).IsRequired();
            builder.Property(l => l.Flag).HasMaxLength(16);

            builder.HasIndex(l => l.Code).IsUnique();
        }
    }
}
