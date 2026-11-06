using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Identity
{
    public class ApplicationUserConfiguration : IEntityTypeConfiguration<ApplicationUser>
    {
        public void Configure(EntityTypeBuilder<ApplicationUser> builder)
        {
            // Mỗi số điện thoại chỉ thuộc 1 tài khoản, để tài khoản bị khóa
            // không đăng ký lại được bằng SĐT cũ
            builder.Property(u => u.PhoneNumber).HasMaxLength(20);

            builder.HasIndex(u => u.PhoneNumber)
                .IsUnique()
                .HasFilter("[PhoneNumber] IS NOT NULL");
        }
    }
}
