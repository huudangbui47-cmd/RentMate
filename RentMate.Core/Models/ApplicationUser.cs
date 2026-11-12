using Microsoft.AspNetCore.Identity;

namespace RentMate.Core.Models
{
    public class ApplicationUser : IdentityUser
    {
        public string FullName { get; set; } = string.Empty;

        public string? AvatarUrl { get; set; }

        public string? Address { get; set; }

        public bool IsActive { get; set; } = true;

        public DateTime CreatedAt { get; set; }
            = DateTime.UtcNow;

        // Thông tin ngân hàng để rút tiền (bắt buộc trước lần rút đầu tiên).
        // Họ tên chủ tài khoản lưu dạng không dấu, viết hoa: "NGUYEN VAN A".
        public string? BankAccountName { get; set; }

        public string? BankName { get; set; }

        public string? BankAccountNumber { get; set; }

        public ICollection<Item> Items { get; set; }
            = new List<Item>();

        public ICollection<Rental> Rentals { get; set; }
            = new List<Rental>();

        public ICollection<Review> WrittenReviews { get; set; }
            = new List<Review>();

        public ICollection<Review> ReceivedReviews { get; set; }
            = new List<Review>();

        public ICollection<ConditionReport> ConditionReports { get; set; }
            = new List<ConditionReport>();

        public ICollection<Notification> Notifications { get; set; }
            = new List<Notification>();

        public ICollection<WalletTransaction> WalletTransactions { get; set; }
            = new List<WalletTransaction>();
    }
}
