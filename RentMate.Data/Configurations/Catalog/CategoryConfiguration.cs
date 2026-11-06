using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Catalog
{
    public class CategoryConfiguration : IEntityTypeConfiguration<Category>
    {
        public void Configure(EntityTypeBuilder<Category> builder)
        {
            builder.Property(c => c.Id).HasColumnName("CategoryId");
        }
    }
}
