using Microsoft.EntityFrameworkCore;
using RentMate.Api.Data;
using RentMate.Api.DTOs.Payments;
using RentMate.Api.Models;
using RentMate.Api.Models.Enums;
using RentMate.Api.Services.Interfaces;

namespace RentMate.Api.Services
{
    public class PaymentService : IPaymentService
    {
        private readonly ApplicationDbContext _context;

        public PaymentService(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<PaymentDto> PayAsync(
            int rentalId,
            PayPaymentDto dto,
            string userId)
        {
            var rental = await _context.Rentals
                .Include(r => r.Item)
                .FirstOrDefaultAsync(r =>
                    r.RentalId == rentalId);

            if (rental == null)
            {
                throw new ArgumentException(
                    "Rental does not exist.");
            }

            // Chỉ người thuê thanh toán
            if (rental.RenterId != userId)
            {
                throw new UnauthorizedAccessException();
            }

            // Chỉ thanh toán sau khi owner đã duyệt
            if (rental.Status != RentalStatus.Approved &&
                rental.Status != RentalStatus.WaitingForPickup)
            {
                throw new InvalidOperationException(
                    "Rental must be approved before payment.");
            }

            // Giai đoạn này chỉ xử lý:
            // - Tiền thuê
            // - Tiền cọc
            if (dto.PaymentType != PaymentType.RentalFee &&
                dto.PaymentType != PaymentType.Deposit)
            {
                throw new ArgumentException(
                    "Only rental fee and deposit can be paid at this stage.");
            }

            if (!Enum.IsDefined(
                typeof(PaymentMethod),
                dto.PaymentMethod))
            {
                throw new ArgumentException(
                    "Invalid payment method.");
            }

            // Không thanh toán trùng cùng loại
            var alreadyPaid =
                await _context.Payments.AnyAsync(p =>
                    p.RentalId == rentalId &&
                    p.PaymentType == dto.PaymentType &&
                    p.Status == PaymentStatus.Paid);

            if (alreadyPaid)
            {
                throw new InvalidOperationException(
                    "This payment has already been completed.");
            }

            decimal amount;

            if (dto.PaymentType == PaymentType.RentalFee)
            {
                amount = rental.TotalPrice;
            }
            else
            {
                amount = rental.DepositAmount;
            }

            var payment = new Payment
            {
                RentalId = rentalId,

                Amount = amount,

                PaymentType = dto.PaymentType,

                PaymentMethod = dto.PaymentMethod,

                Status = PaymentStatus.Paid,

                TransactionCode =
                    dto.TransactionCode?.Trim(),

                PaidAt = DateTime.UtcNow,

                CreatedAt = DateTime.UtcNow
            };

            _context.Payments.Add(payment);

            await _context.SaveChangesAsync();

            return ToDto(payment);
        }

        public async Task<List<PaymentDto>>
            GetByRentalAsync(
                int rentalId,
                string userId)
        {
            var rental = await _context.Rentals
                .Include(r => r.Item)
                .AsNoTracking()
                .FirstOrDefaultAsync(r =>
                    r.RentalId == rentalId);

            if (rental == null)
            {
                throw new ArgumentException(
                    "Rental does not exist.");
            }

            // Owner và renter đều được xem
            if (rental.RenterId != userId &&
                rental.Item.OwnerId != userId)
            {
                throw new UnauthorizedAccessException();
            }

            var payments =
                await _context.Payments
                    .AsNoTracking()
                    .Where(p =>
                        p.RentalId == rentalId)
                    .OrderBy(p => p.CreatedAt)
                    .ToListAsync();

            return payments
                .Select(ToDto)
                .ToList();
        }

        private static PaymentDto ToDto(
            Payment payment)
        {
            return new PaymentDto
            {
                PaymentId =
                    payment.PaymentId,

                RentalId =
                    payment.RentalId,

                Amount =
                    payment.Amount,

                PaymentType =
                    payment.PaymentType.ToString(),

                PaymentMethod =
                    payment.PaymentMethod.ToString(),

                PaymentStatus =
                    payment.Status.ToString(),

                TransactionCode =
                    payment.TransactionCode,

                PaidAt =
                    payment.PaidAt,

                CreatedAt =
                    payment.CreatedAt
            };
        }
    }
}