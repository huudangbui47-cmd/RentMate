namespace RentMate.Core.ViewModels
{
    public class DashboardViewModel
    {
        public int TotalUsers { get; set; }
        public int TotalItems { get; set; }
        public int AvailableItems { get; set; }
        public int PendingApprovalItems { get; set; }
        public int PendingRentals { get; set; }
        public int ActiveRentals { get; set; }
        public int OverdueRentals { get; set; }
        public decimal TotalRevenue { get; set; }

        public List<RentalListItemViewModel> LatestRentals { get; set; } = new();
        public List<MonthlyRevenueViewModel> MonthlyRevenue { get; set; } = new();
        public List<TopRentedItemViewModel> TopItems { get; set; } = new();
        public List<CategoryStatViewModel> CategoryStats { get; set; } = new();
    }
}
