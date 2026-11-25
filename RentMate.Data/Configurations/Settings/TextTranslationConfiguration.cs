using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Settings
{
    public class TextTranslationConfiguration : IEntityTypeConfiguration<TextTranslation>
    {
        public void Configure(EntityTypeBuilder<TextTranslation> builder)
        {
            builder.Property(t => t.Id).HasColumnName("TextTranslationId");

            builder.Property(t => t.Value).HasMaxLength(2000).IsRequired();

            // Mỗi câu chỉ có một bản dịch cho mỗi ngôn ngữ
            builder.HasIndex(t => new { t.TextResourceId, t.LanguageId }).IsUnique();

            // Xóa câu hoặc ngôn ngữ thì xóa luôn bản dịch của nó
            builder.HasOne(t => t.TextResource)
                .WithMany(r => r.Translations)
                .HasForeignKey(t => t.TextResourceId)
                .OnDelete(DeleteBehavior.Cascade);

            builder.HasOne(t => t.Language)
                .WithMany(l => l.Translations)
                .HasForeignKey(t => t.LanguageId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
