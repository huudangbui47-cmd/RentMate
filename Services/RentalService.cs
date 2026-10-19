using Microsoft.EntityFrameworkCore;
using RentMate.Api.Data;
using RentMate.Api.DTOs.Rentals;
using RentMate.Api.Models;
using RentMate.Api.Models.Enums;
using RentMate.Api.Services.Interfaces;

namespace RentMate.Api.Services
{
    public class RentalService : IRentalService
    {
        private readonly ApplicationDbContext _context;

        public RentalService(ApplicationDbContext context)
        {
            _context = context;
        }

        // =========================
        // CREATE RENTAL REQUEST
        // =========================
        public async Task<RentalDto> CreateAsync(
            CreateRentalDto dto,
            string renterId)
        {
            if (dto.StartDate.Date < DateTime.UtcNow.Date)
            {
                throw new ArgumentException(
                    "Start date cannot be in the past.");
            }

            if (dto.EndDate.Date < dto.StartDate.Date)
            {
                throw new ArgumentException(
                    "End date cannot be before start date.");
            }

            var item = await _context.Items
                .Include(i => i.Owner)
                .FirstOrDefaultAsync(i =>
                    i.ItemId == dto.ItemId &&
                    i.Status != ItemStatus.Hidden);

            if (item == null)
            {
                throw new ArgumentException(
                    "Item does not exist.");
            }

            // Không được thuê đồ của chính mình
            if (item.OwnerId == renterId)
            {
                throw new InvalidOperationException(
                    "You cannot rent your own item.");
            }

            if (item.Status == ItemStatus.Unavailable)
            {
                throw new InvalidOperationException(
                    "This item is currently unavailable.");
            }

            var numberOfDays =
                (dto.EndDate.Date - dto.StartDate.Date).Days + 1;

            var rental = new Rental
            {
                ItemId = item.ItemId,
                RenterId = renterId,

                StartDate = dto.StartDate.Date,
                EndDate = dto.EndDate.Date,

                // Giữ giá tại thời điểm tạo đơn
                PricePerDay = item.PricePerDay,
                DepositAmount = item.DepositAmount,

                TotalPrice =
                    item.PricePerDay * numberOfDays,

                RequestNote = dto.RequestNote,

                Status = RentalStatus.Pending,

                RequestedAt = DateTime.UtcNow
            };

            _context.Rentals.Add(rental);

            await _context.SaveChangesAsync();

            var result =
                await GetRentalDtoAsync(rental.RentalId);

            return result!;
        }

        // =========================
        // GET MY RENTALS
        // =========================
        public async Task<List<RentalDto>> GetMyRentalsAsync(
            string userId)
        {
            var rentals = await RentalQuery()
                .Where(r =>
                    r.RenterId == userId ||
                    r.Item.OwnerId == userId)
                .OrderByDescending(r => r.RequestedAt)
                .ToListAsync();

            return rentals
                .Select(ToDto)
                .ToList();
        }

        // =========================
        // GET RENTAL DETAIL
        // =========================
        public async Task<RentalDto?> GetByIdAsync(
            int rentalId,
            string userId)
        {
            var rental = await RentalQuery()
                .FirstOrDefaultAsync(r =>
                    r.RentalId == rentalId &&
                    (
                        r.RenterId == userId ||
                        r.Item.OwnerId == userId
                    ));

            if (rental == null)
            {
                return null;
            }

            return ToDto(rental);
        }

        // =========================
        // APPROVE
        // =========================
        public async Task<bool> ApproveAsync(
            int rentalId,
            string ownerId)
        {
            var rental = await _context.Rentals
                .Include(r => r.Item)
                .FirstOrDefaultAsync(r =>
                    r.RentalId == rentalId);

            if (rental == null)
            {
                return false;
            }

            if (rental.Item.OwnerId != ownerId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.Status != RentalStatus.Pending)
            {
                throw new InvalidOperationException(
                    "Only pending rentals can be approved.");
            }

            // Kiểm tra lịch thuê trùng
            var hasConflict =
                await _context.Rentals.AnyAsync(r =>
                    r.RentalId != rentalId &&
                    r.ItemId == rental.ItemId &&

                    (
                        r.Status == RentalStatus.Approved ||
                        r.Status == RentalStatus.WaitingForPickup ||
                        r.Status == RentalStatus.Rented
                    ) &&

                    rental.StartDate <= r.EndDate &&
                    rental.EndDate >= r.StartDate);

            if (hasConflict)
            {
                throw new InvalidOperationException(
                    "This item is already booked for this period.");
            }

            rental.Status = RentalStatus.Approved;
            rental.ApprovedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return true;
        }

        // =========================
        // REJECT
        // =========================
        public async Task<bool> RejectAsync(
            int rentalId,
            string ownerId)
        {
            var rental = await _context.Rentals
                .Include(r => r.Item)
                .FirstOrDefaultAsync(r =>
                    r.RentalId == rentalId);

            if (rental == null)
            {
                return false;
            }

            if (rental.Item.OwnerId != ownerId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.Status != RentalStatus.Pending)
            {
                throw new InvalidOperationException(
                    "Only pending rentals can be rejected.");
            }

            rental.Status = RentalStatus.Rejected;

            await _context.SaveChangesAsync();

            return true;
        }

        // =========================
        // PICKUP
        // =========================
        public async Task<bool> PickupAsync(
            int rentalId,
            string ownerId)
        {
            var rental = await _context.Rentals
                .Include(r => r.Item)
                .FirstOrDefaultAsync(r =>
                    r.RentalId == rentalId);

            if (rental == null)
            {
                return false;
            }

            if (rental.Item.OwnerId != ownerId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.Status != RentalStatus.Approved &&
                rental.Status != RentalStatus.WaitingForPickup)
            {
                throw new InvalidOperationException(
                    "Rental is not ready for pickup.");
            }

            // =========================
            // PHẢI CÓ BEFORE REPORT
            // =========================
            var hasBeforeReport =
                await _context.ConditionReports
                    .AnyAsync(c =>
                        c.RentalId == rentalId &&
                        c.ReportType ==
                            ConditionReportType.BeforeRental);

            if (!hasBeforeReport)
            {
                throw new InvalidOperationException(
                    "Before-rental condition report is required before pickup.");
            }

            rental.Status = RentalStatus.Rented;
            rental.ReceivedAt = DateTime.UtcNow;

            rental.Item.Status = ItemStatus.Rented;

            await _context.SaveChangesAsync();

            return true;
        }

        // =========================
        // RETURN
        // =========================
        public async Task<bool> ReturnAsync(
            int rentalId,
            string renterId)
        {
            var rental = await _context.Rentals
                .FirstOrDefaultAsync(r =>
                    r.RentalId == rentalId);

            if (rental == null)
            {
                return false;
            }

            if (rental.RenterId != renterId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.Status != RentalStatus.Rented)
            {
                throw new InvalidOperationException(
                    "Only rented items can be returned.");
            }

            rental.Status = RentalStatus.Returned;
            rental.ReturnedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return true;
        }

        // =========================
        // COMPLETE
        // =========================
        public async Task<bool> CompleteAsync(
            int rentalId,
            string ownerId)
        {
            var rental = await _context.Rentals
                .Include(r => r.Item)
                .FirstOrDefaultAsync(r =>
                    r.RentalId == rentalId);

            if (rental == null)
            {
                return false;
            }

            if (rental.Item.OwnerId != ownerId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.Status != RentalStatus.Returned)
            {
                throw new InvalidOperationException(
                    "Rental must be returned before completion.");
            }

            // =========================
            // PHẢI CÓ AFTER REPORT
            // =========================
            var hasAfterReport =
                await _context.ConditionReports
                    .AnyAsync(c =>
                        c.RentalId == rentalId &&
                        c.ReportType ==
                            ConditionReportType.AfterRental);

            if (!hasAfterReport)
            {
                throw new InvalidOperationException(
                    "After-rental condition report is required before completion.");
            }

            rental.Status = RentalStatus.Completed;
            rental.CompletedAt = DateTime.UtcNow;

            rental.Item.Status = ItemStatus.Available;

            await _context.SaveChangesAsync();

            return true;
        }

        // =========================
        // COMMON QUERY
        // =========================
        private IQueryable<Rental> RentalQuery()
        {
            return _context.Rentals
                .AsNoTracking()

                .Include(r => r.Item)
                    .ThenInclude(i => i.Owner)

                .Include(r => r.Renter);
        }

        // =========================
        // GET DTO INTERNAL
        // =========================
        private async Task<RentalDto?> GetRentalDtoAsync(
            int rentalId)
        {
            var rental = await RentalQuery()
                .FirstOrDefaultAsync(r =>
                    r.RentalId == rentalId);

            if (rental == null)
            {
                return null;
            }

            return ToDto(rental);
        }

        // =========================
        // ENTITY -> DTO
        // =========================
        private static RentalDto ToDto(
            Rental rental)
        {
            return new RentalDto
            {
                RentalId = rental.RentalId,

                ItemId = rental.ItemId,
                ItemName = rental.Item.ItemName,

                RenterId = rental.RenterId,
                RenterName = rental.Renter.FullName,

                OwnerId = rental.Item.OwnerId,
                OwnerName = rental.Item.Owner.FullName,

                StartDate = rental.StartDate,
                EndDate = rental.EndDate,

                PricePerDay = rental.PricePerDay,
                DepositAmount = rental.DepositAmount,
                TotalPrice = rental.TotalPrice,

                Status = rental.Status.ToString(),

                RequestNote = rental.RequestNote,
                RequestedAt = rental.RequestedAt
            };
        }
    }
}