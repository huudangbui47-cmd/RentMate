using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Settings
{
    public class TextResourceConfiguration : IEntityTypeConfiguration<TextResource>
    {
        public void Configure(EntityTypeBuilder<TextResource> builder)
        {
            builder.Property(t => t.Id).HasColumnName("TextResourceId");

            // 450 ký tự: giới hạn để SQL Server tạo được chỉ mục duy nhất (900 byte)
            builder.Property(t => t.Key).HasMaxLength(450).IsRequired();
            builder.Property(t => t.Note).HasMaxLength(500);

            builder.HasIndex(t => t.Key).IsUnique();
        }
    }
}
