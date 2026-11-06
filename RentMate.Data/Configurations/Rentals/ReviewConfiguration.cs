using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RentMate.Core.Models;

namespace RentMate.Data.Configurations.Rentals
{
    public class ReviewConfiguration : IEntityTypeConfiguration<Review>
    {
        public void Configure(EntityTypeBuilder<Review> builder)
        {
            builder.Property(r => r.Id).HasColumnName("ReviewId");

            // Rental 1 - N Review
            builder.HasOne(r => r.Rental)
                .WithMany(r => r.Reviews)
                .HasForeignKey(r => r.RentalId)
                .OnDelete(DeleteBehavior.Cascade);

            // User 1 - N Review: người viết
            builder.HasOne(r => r.Reviewer)
                .WithMany(u => u.WrittenReviews)
                .HasForeignKey(r => r.ReviewerId)
                .OnDelete(DeleteBehavior.Restrict);

            // User 1 - N Review: người nhận
            builder.HasOne(r => r.ReviewedUser)
                .WithMany(u => u.ReceivedReviews)
                .HasForeignKey(r => r.ReviewedUserId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
