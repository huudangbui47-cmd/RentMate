using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Catalog
{
    public class ItemImageConfiguration : IEntityTypeConfiguration<ItemImage>
    {
        public void Configure(EntityTypeBuilder<ItemImage> builder)
        {
            builder.Property(i => i.Id).HasColumnName("ItemImageId");

            // Item 1 - N ItemImage
            builder.HasOne(i => i.Item)
                .WithMany(i => i.Images)
                .HasForeignKey(i => i.ItemId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
