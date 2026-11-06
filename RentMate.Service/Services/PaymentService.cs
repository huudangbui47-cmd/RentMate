using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.ViewModels;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class PaymentService : IPaymentService
    {
        private readonly IUnitOfWork _unitOfWork;

        public PaymentService(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork;
        }

        public async Task<PaymentListViewModel> SearchAsync(PaymentStatus? status, PaymentType? paymentType, DateTime? fromDate, DateTime? toDate, int page = 1)
        {
            var query = _unitOfWork.Payments.BuildQuery(p => true);

            if (status.HasValue)
                query = query.Where(p => p.Status == status.Value);

            if (paymentType.HasValue)
                query = query.Where(p => p.PaymentType == paymentType.Value);

            if (fromDate.HasValue)
            {
                DateTime start = fromDate.Value.Date.ToUniversalTime();

                query = query.Where(p => p.CreatedAt >= start);
            }

            if (toDate.HasValue)
            {
                DateTime end = toDate.Value.Date.AddDays(1).ToUniversalTime();

                query = query.Where(p => p.CreatedAt < end);
            }

            int totalCount = await query.CountAsync();

            decimal totalPaid = await query
                .Where(p => p.Status == PaymentStatus.Paid)
                .SumAsync(p => (decimal?)p.Amount) ?? 0m;

            const int pageSize = 10;
            page = Math.Clamp(page, 1, Math.Max(1, (totalCount + pageSize - 1) / pageSize));

            var payments = await query
                .OrderByDescending(p => p.CreatedAt)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(p => new PaymentViewModel
                {
                    Id = p.Id,
                    RentalId = p.RentalId,
                    ItemName = p.Rental.Item.ItemName,
                    RenterName = p.Rental.Renter.FullName,
                    Amount = p.Amount,
                    PaymentType = p.PaymentType,
                    PaymentMethod = p.PaymentMethod,
                    Status = p.Status,
                    TransactionCode = p.TransactionCode,
                    PaidAt = p.PaidAt,
                    CreatedAt = p.CreatedAt
                })
                .ToListAsync();

            return new PaymentListViewModel
            {
                Status = status,
                PaymentType = paymentType,
                FromDate = fromDate,
                ToDate = toDate,
                TotalPaidAmount = totalPaid,
                Payments = payments,
                Page = page, PageSize = pageSize, TotalCount = totalCount
            };
        }
    }
}
