using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Identity
{
    public class AuditLogConfiguration : IEntityTypeConfiguration<AuditLog>
    {
        public void Configure(EntityTypeBuilder<AuditLog> builder)
        {
            builder.Property(a => a.Id).HasColumnName("AuditLogId");

            builder.Property(a => a.Action).HasMaxLength(100).IsRequired();
            builder.Property(a => a.EntityName).HasMaxLength(100).IsRequired();
            builder.Property(a => a.EntityId).HasMaxLength(450);
            builder.Property(a => a.Description).HasMaxLength(1000);
            builder.Property(a => a.IpAddress).HasMaxLength(64);

            builder.HasIndex(a => a.CreatedAt);

            // User 1 - N AuditLog. Giữ lại log khi xóa user.
            builder.HasOne(a => a.User)
                .WithMany()
                .HasForeignKey(a => a.UserId)
                .OnDelete(DeleteBehavior.SetNull);
        }
    }
}
