using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Catalog
{
    public class FavoriteConfiguration : IEntityTypeConfiguration<Favorite>
    {
        public void Configure(EntityTypeBuilder<Favorite> builder)
        {
            builder.Property(f => f.Id).HasColumnName("FavoriteId");

            // Một khách chỉ lưu một món một lần
            builder.HasIndex(f => new { f.UserId, f.ItemId }).IsUnique();

            // Tài khoản chỉ khóa (xóa mềm) nên không xóa dây chuyền
            builder.HasOne(f => f.User)
                .WithMany()
                .HasForeignKey(f => f.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            // Danh sách yêu thích không phải lịch sử, đồ bị xóa thì bỏ theo
            builder.HasOne(f => f.Item)
                .WithMany()
                .HasForeignKey(f => f.ItemId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
