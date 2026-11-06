using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class DashboardService : IDashboardService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly UserManager<ApplicationUser> _userManager;

        public DashboardService(IUnitOfWork unitOfWork, UserManager<ApplicationUser> userManager)
        {
            _unitOfWork = unitOfWork;
            _userManager = userManager;
        }

        public async Task<DashboardViewModel> GetAsync()
        {
            int totalUsers = await _userManager.Users.CountAsync();
            int totalItems = await _unitOfWork.Items.BuildQuery(i => i.Status != ItemStatus.Hidden).CountAsync();
            int availableItems = await _unitOfWork.Items.BuildQuery(i => i.Status == ItemStatus.Available).CountAsync();
            int pendingRentals = await _unitOfWork.Rentals.BuildQuery(r => r.Status == RentalStatus.Pending).CountAsync();

            int activeRentals = await _unitOfWork.Rentals
                .BuildQuery(r =>
                    r.Status == RentalStatus.Approved ||
                    r.Status == RentalStatus.WaitingForPickup ||
                    r.Status == RentalStatus.Rented)
                .CountAsync();

            DateTime today = DateTime.UtcNow.Date;

            int overdueRentals = await _unitOfWork.Rentals
                .BuildQuery(r =>
                    r.Status == RentalStatus.Overdue ||
                    (r.Status == RentalStatus.Rented && r.EndDate < today))
                .CountAsync();

            // Doanh thu = phí thuê đã thanh toán (tiền cọc không tính là doanh thu)
            decimal totalRevenue = await _unitOfWork.Payments
                .BuildQuery(p => p.Status == PaymentStatus.Paid && p.PaymentType == PaymentType.RentalFee)
                .SumAsync(p => (decimal?)p.Amount) ?? 0m;

            var latestRentals = await _unitOfWork.Rentals
                .BuildQuery(r => true)
                .OrderByDescending(r => r.RequestedAt)
                .Take(5)
                .Select(r => new RentalListItemViewModel
                {
                    Id = r.Id,
                    ItemName = r.Item.ItemName,
                    RenterName = r.Renter.FullName,
                    OwnerName = r.Item.Owner.FullName,
                    StartDate = r.StartDate,
                    EndDate = r.EndDate,
                    TotalPrice = r.TotalPrice,
                    Status = r.Status,
                    RequestedAt = r.RequestedAt
                })
                .ToListAsync();

            // Doanh thu 6 tháng gần nhất, tháng không có giao dịch hiển thị 0
            DateTime firstMonth = new DateTime(today.Year, today.Month, 1, 0, 0, 0, DateTimeKind.Utc).AddMonths(-5);

            var revenueRaw = await _unitOfWork.Payments
                .BuildQuery(p => p.Status == PaymentStatus.Paid && p.PaymentType == PaymentType.RentalFee)
                .Select(p => new { Date = p.PaidAt ?? p.CreatedAt, p.Amount })
                .Where(x => x.Date >= firstMonth)
                .GroupBy(x => new { x.Date.Year, x.Date.Month })
                .Select(g => new { g.Key.Year, g.Key.Month, Amount = g.Sum(x => x.Amount) })
                .ToListAsync();

            var monthlyRevenue = Enumerable.Range(0, 6)
                .Select(i => firstMonth.AddMonths(i))
                .Select(m => new MonthlyRevenueViewModel
                {
                    Year = m.Year,
                    Month = m.Month,
                    Revenue = revenueRaw.Where(x => x.Year == m.Year && x.Month == m.Month).Sum(x => x.Amount)
                })
                .ToList();

            var topItems = await _unitOfWork.Items
                .BuildQuery(i => i.Rentals.Any())
                .OrderByDescending(i => i.Rentals.Count)
                .Take(5)
                .Select(i => new TopRentedItemViewModel
                {
                    ItemName = i.ItemName,
                    OwnerName = i.Owner.FullName,
                    RentalCount = i.Rentals.Count
                })
                .ToListAsync();

            var categoryStats = await _unitOfWork.Categories
                .BuildQuery(c => c.IsActive)
                .Select(c => new CategoryStatViewModel
                {
                    CategoryName = c.CategoryName,
                    ItemCount = c.Items.Count(i => i.Status != ItemStatus.Hidden)
                })
                .OrderByDescending(c => c.ItemCount)
                .Take(6)
                .ToListAsync();

            return new DashboardViewModel
            {
                TotalUsers = totalUsers,
                TotalItems = totalItems,
                AvailableItems = availableItems,
                PendingRentals = pendingRentals,
                ActiveRentals = activeRentals,
                OverdueRentals = overdueRentals,
                TotalRevenue = totalRevenue,
                LatestRentals = latestRentals,
                MonthlyRevenue = monthlyRevenue,
                TopItems = topItems,
                CategoryStats = categoryStats
            };
        }
    }
}
