using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Rentals;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class RentalService : IRentalService
    {
        private readonly IUnitOfWork _unitOfWork;

        public RentalService(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork;
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

            var item = await _unitOfWork.Items
                .BuildQuery(i =>
                    i.Id == dto.ItemId &&
                    i.Status != ItemStatus.Hidden)
                .FirstOrDefaultAsync();

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
                ItemId = item.Id,
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

            await _unitOfWork.Rentals.AddAsync(rental);

            await _unitOfWork.SaveChangesAsync();

            var result =
                await GetRentalDtoAsync(rental.Id);

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
                    r.Id == rentalId &&
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
            var rental = await GetRentalWithItemAsync(rentalId);

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
            var hasConflict = await _unitOfWork.Rentals
                .BuildQuery(r =>
                    r.Id != rentalId &&
                    r.ItemId == rental.ItemId &&

                    (
                        r.Status == RentalStatus.Approved ||
                        r.Status == RentalStatus.WaitingForPickup ||
                        r.Status == RentalStatus.Rented
                    ) &&

                    rental.StartDate <= r.EndDate &&
                    rental.EndDate >= r.StartDate)
                .AnyAsync();

            if (hasConflict)
            {
                throw new InvalidOperationException(
                    "This item is already booked for this period.");
            }

            rental.Status = RentalStatus.Approved;
            rental.ApprovedAt = DateTime.UtcNow;

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // REJECT
        // =========================
        public async Task<bool> RejectAsync(
            int rentalId,
            string ownerId)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

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

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // PICKUP
        // =========================
        public async Task<bool> PickupAsync(
            int rentalId,
            string ownerId)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

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
            var hasBeforeReport = await _unitOfWork.ConditionReports
                .BuildQuery(c =>
                    c.RentalId == rentalId &&
                    c.ReportType ==
                        ConditionReportType.BeforeRental)
                .AnyAsync();

            if (!hasBeforeReport)
            {
                throw new InvalidOperationException(
                    "Before-rental condition report is required before pickup.");
            }

            rental.Status = RentalStatus.Rented;
            rental.ReceivedAt = DateTime.UtcNow;

            rental.Item.Status = ItemStatus.Rented;

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // RETURN
        // =========================
        public async Task<bool> ReturnAsync(
            int rentalId,
            string renterId)
        {
            var rental = await _unitOfWork.Rentals.GetByIdAsync(rentalId);

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

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // COMPLETE
        // =========================
        public async Task<bool> CompleteAsync(
            int rentalId,
            string ownerId)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

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
            var hasAfterReport = await _unitOfWork.ConditionReports
                .BuildQuery(c =>
                    c.RentalId == rentalId &&
                    c.ReportType ==
                        ConditionReportType.AfterRental)
                .AnyAsync();

            if (!hasAfterReport)
            {
                throw new InvalidOperationException(
                    "After-rental condition report is required before completion.");
            }

            rental.Status = RentalStatus.Completed;
            rental.CompletedAt = DateTime.UtcNow;

            rental.Item.Status = ItemStatus.Available;

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // TRANG QUẢN TRỊ
        // =========================
        public async Task<RentalListViewModel> SearchAsync(string? searchTerm, RentalStatus? status, int page = 1)
        {
            var query = _unitOfWork.Rentals.BuildQuery(r => true);

            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                string keyword = searchTerm.Trim();
                int.TryParse(keyword.TrimStart('#'), out int rentalId);

                query = query.Where(r =>
                    r.Id == rentalId ||
                    r.Item.ItemName.Contains(keyword) ||
                    r.Renter.FullName.Contains(keyword) ||
                    r.Item.Owner.FullName.Contains(keyword));
            }

            if (status.HasValue)
                query = query.Where(r => r.Status == status.Value);

            int totalCount = await query.CountAsync();
            const int pageSize = 10;
            page = Math.Clamp(page, 1, Math.Max(1, (totalCount + pageSize - 1) / pageSize));

            var rentals = await query
                .OrderByDescending(r => r.RequestedAt)
                .Skip((page - 1) * pageSize).Take(pageSize)
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

            return new RentalListViewModel
            {
                SearchTerm = searchTerm,
                Status = status,
                Rentals = rentals,
                Page = page, PageSize = pageSize, TotalCount = totalCount
            };
        }

        public async Task<RentalDetailsViewModel?> GetDetailsAsync(int id)
        {
            return await _unitOfWork.Rentals
                .BuildQuery(r => r.Id == id)
                .Select(r => new RentalDetailsViewModel
                {
                    Id = r.Id,
                    ItemName = r.Item.ItemName,
                    CategoryName = r.Item.Category.CategoryName,

                    RenterName = r.Renter.FullName,
                    RenterEmail = r.Renter.Email,
                    RenterPhone = r.Renter.PhoneNumber,

                    OwnerName = r.Item.Owner.FullName,
                    OwnerEmail = r.Item.Owner.Email,
                    OwnerPhone = r.Item.Owner.PhoneNumber,

                    StartDate = r.StartDate,
                    EndDate = r.EndDate,
                    PricePerDay = r.PricePerDay,
                    DepositAmount = r.DepositAmount,
                    TotalPrice = r.TotalPrice,
                    RequestNote = r.RequestNote,
                    Status = r.Status,

                    RequestedAt = r.RequestedAt,
                    ApprovedAt = r.ApprovedAt,
                    ReceivedAt = r.ReceivedAt,
                    ReturnedAt = r.ReturnedAt,
                    CompletedAt = r.CompletedAt,

                    Payments = r.Payments
                        .OrderBy(p => p.CreatedAt)
                        .Select(p => new PaymentViewModel
                        {
                            Id = p.Id,
                            RentalId = p.RentalId,
                            Amount = p.Amount,
                            PaymentType = p.PaymentType,
                            PaymentMethod = p.PaymentMethod,
                            Status = p.Status,
                            TransactionCode = p.TransactionCode,
                            PaidAt = p.PaidAt,
                            CreatedAt = p.CreatedAt
                        })
                        .ToList(),

                    ConditionReports = r.ConditionReports
                        .OrderBy(c => c.CreatedAt)
                        .Select(c => new ConditionReportViewModel
                        {
                            Id = c.Id,
                            ReportType = c.ReportType,
                            Condition = c.Condition,
                            Description = c.Description,
                            CreatedByName = c.CreatedByUser.FullName,
                            CreatedAt = c.CreatedAt,
                            ImageUrls = c.Images.Select(i => i.ImageUrl).ToList()
                        })
                        .ToList()
                })
                .FirstOrDefaultAsync();
        }

        // =========================
        // COMMON QUERY
        // =========================
        private IQueryable<Rental> RentalQuery()
        {
            return _unitOfWork.Rentals
                .BuildQuery(r => true)

                .Include(r => r.Item)
                    .ThenInclude(i => i.Owner)

                .Include(r => r.Renter);
        }

        // Lấy rental (có tracking) kèm Item để kiểm tra chủ đồ và cập nhật trạng thái
        private async Task<Rental?> GetRentalWithItemAsync(int rentalId)
        {
            var rental = await _unitOfWork.Rentals.GetByIdAsync(rentalId);

            if (rental == null)
            {
                return null;
            }

            // EF tự gắn rental.Item khi Item được load vào cùng DbContext
            await _unitOfWork.Items.GetByIdAsync(rental.ItemId);

            return rental;
        }

        // =========================
        // GET DTO INTERNAL
        // =========================
        private async Task<RentalDto?> GetRentalDtoAsync(
            int rentalId)
        {
            var rental = await RentalQuery()
                .FirstOrDefaultAsync(r =>
                    r.Id == rentalId);

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
                RentalId = rental.Id,

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
