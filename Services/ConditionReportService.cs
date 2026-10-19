using Microsoft.EntityFrameworkCore;
using RentMate.Api.Data;
using RentMate.Api.DTOs.ConditionReports;
using RentMate.Api.Models;
using RentMate.Api.Models.Enums;
using RentMate.Api.Services.Interfaces;

namespace RentMate.Api.Services
{
    public class ConditionReportService
        : IConditionReportService
    {
        private readonly ApplicationDbContext _context;

        public ConditionReportService(
            ApplicationDbContext context)
        {
            _context = context;
        }

        // =========================
        // CREATE REPORT
        // =========================
        public async Task<ConditionReportDto> CreateAsync(
            int rentalId,
            CreateConditionReportDto dto,
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

            // MVP:
            // chỉ chủ đồ lập biên bản tình trạng
            if (rental.Item.OwnerId != userId)
            {
                throw new UnauthorizedAccessException(
                    "Only the item owner can create condition reports.");
            }

            if (!Enum.IsDefined(
                typeof(ConditionReportType),
                dto.ReportType))
            {
                throw new ArgumentException(
                    "Invalid report type.");
            }

            if (!Enum.IsDefined(
                typeof(ItemCondition),
                dto.Condition))
            {
                throw new ArgumentException(
                    "Invalid item condition.");
            }

            // Không cho tạo trùng Before/After
            var alreadyExists =
                await _context.ConditionReports
                    .AnyAsync(c =>
                        c.RentalId == rentalId &&
                        c.ReportType == dto.ReportType);

            if (alreadyExists)
            {
                throw new InvalidOperationException(
                    "This condition report already exists.");
            }

            // =========================
            // BEFORE RENTAL
            // =========================
            if (dto.ReportType ==
                ConditionReportType.BeforeRental)
            {
                if (rental.Status != RentalStatus.Approved &&
                    rental.Status != RentalStatus.WaitingForPickup)
                {
                    throw new InvalidOperationException(
                        "Before-rental report can only be created after approval and before pickup.");
                }
            }

            // =========================
            // AFTER RENTAL
            // =========================
            if (dto.ReportType ==
                ConditionReportType.AfterRental)
            {
                if (rental.Status != RentalStatus.Returned)
                {
                    throw new InvalidOperationException(
                        "After-rental report can only be created after the item is returned.");
                }
            }

            var report = new ConditionReport
            {
                RentalId = rentalId,

                CreatedByUserId = userId,

                ReportType = dto.ReportType,

                Condition = dto.Condition,

                Description = dto.Description,

                CreatedAt = DateTime.UtcNow
            };

            foreach (var imageUrl in dto.ImageUrls)
            {
                if (string.IsNullOrWhiteSpace(imageUrl))
                    continue;

                report.Images.Add(
                    new ConditionReportImage
                    {
                        ImageUrl = imageUrl.Trim(),
                        CreatedAt = DateTime.UtcNow
                    });
            }

            _context.ConditionReports.Add(report);

            await _context.SaveChangesAsync();

            return await GetDtoAsync(
                report.ConditionReportId);
        }

        // =========================
        // GET REPORTS OF RENTAL
        // =========================
        public async Task<List<ConditionReportDto>>
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

            // Chỉ renter và owner được xem
            if (rental.RenterId != userId &&
                rental.Item.OwnerId != userId)
            {
                throw new UnauthorizedAccessException();
            }

            var reports =
                await _context.ConditionReports
                    .AsNoTracking()
                    .Include(c => c.Images)
                    .Where(c =>
                        c.RentalId == rentalId)
                    .OrderBy(c => c.CreatedAt)
                    .ToListAsync();

            return reports
                .Select(ToDto)
                .ToList();
        }

        // =========================
        // GET INTERNAL
        // =========================
        private async Task<ConditionReportDto>
            GetDtoAsync(int reportId)
        {
            var report =
                await _context.ConditionReports
                    .AsNoTracking()
                    .Include(c => c.Images)
                    .FirstAsync(c =>
                        c.ConditionReportId == reportId);

            return ToDto(report);
        }

        // =========================
        // ENTITY -> DTO
        // =========================
        private static ConditionReportDto ToDto(
            ConditionReport report)
        {
            return new ConditionReportDto
            {
                ConditionReportId =
                    report.ConditionReportId,

                RentalId =
                    report.RentalId,

                ReportType =
                    report.ReportType.ToString(),

                Condition =
                    report.Condition.ToString(),

                Description =
                    report.Description,

                CreatedByUserId =
                    report.CreatedByUserId,

                CreatedAt =
                    report.CreatedAt,

                ImageUrls =
                    report.Images
                        .Select(i => i.ImageUrl)
                        .ToList()
            };
        }
    }
}