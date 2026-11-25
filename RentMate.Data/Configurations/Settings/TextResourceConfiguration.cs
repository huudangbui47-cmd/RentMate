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
            // Phân biệt hoa/thường: app có cả "Số tiền" (nhãn) lẫn "số tiền" (giữa câu) là 2 câu khác nhau
            builder.Property(t => t.Key).HasMaxLength(450).IsRequired().UseCollation("Latin1_General_100_CS_AS");
            builder.Property(t => t.Note).HasMaxLength(500);

            builder.HasIndex(t => t.Key).IsUnique();
        }
    }
}
