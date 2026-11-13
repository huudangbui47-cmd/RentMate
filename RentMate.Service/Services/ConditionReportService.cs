using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Service.DTOs.ConditionReports;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class ConditionReportService
        : IConditionReportService
    {
        private readonly IUnitOfWork _unitOfWork;

        public ConditionReportService(
            IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork;
        }

        // =========================
        // CREATE REPORT
        // =========================
        public async Task<ConditionReportDto> CreateAsync(
            int rentalId,
            CreateConditionReportDto dto,
            string userId)
        {
            var rental = await _unitOfWork.Rentals
                .BuildQuery(r => r.Id == rentalId)
                .Include(r => r.Item)
                .FirstOrDefaultAsync();

            if (rental == null)
            {
                throw new ArgumentException(
                    "Đơn thuê không tồn tại.");
            }

            // MVP:
            // chỉ chủ đồ lập biên bản tình trạng
            if (rental.Item.OwnerId != userId)
            {
                throw new UnauthorizedAccessException(
                    "Chỉ chủ đồ mới lập được biên bản.");
            }

            if (!Enum.IsDefined(
                typeof(ConditionReportType),
                dto.ReportType))
            {
                throw new ArgumentException(
                    "Loại biên bản không hợp lệ.");
            }

            if (!Enum.IsDefined(
                typeof(ItemCondition),
                dto.Condition))
            {
                throw new ArgumentException(
                    "Tình trạng đồ không hợp lệ.");
            }

            // Không cho tạo trùng Before/After
            var alreadyExists = await _unitOfWork.ConditionReports
                .BuildQuery(c =>
                    c.RentalId == rentalId &&
                    c.ReportType == dto.ReportType)
                .AnyAsync();

            if (alreadyExists)
            {
                throw new InvalidOperationException(
                    "Biên bản này đã được lập rồi.");
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
                        "Biên bản trước khi giao chỉ lập được sau khi duyệt và trước khi giao đồ.");
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
                        "Biên bản sau khi trả chỉ lập được khi người thuê đã trả đồ.");
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

            await _unitOfWork.ConditionReports.AddAsync(report);

            await _unitOfWork.SaveChangesAsync();

            return await GetDtoAsync(
                report.Id);
        }

        // =========================
        // GET REPORTS OF RENTAL
        // =========================
        public async Task<List<ConditionReportDto>>
            GetByRentalAsync(
                int rentalId,
                string userId)
        {
            var rental = await _unitOfWork.Rentals
                .BuildQuery(r => r.Id == rentalId)
                .Include(r => r.Item)
                .FirstOrDefaultAsync();

            if (rental == null)
            {
                throw new ArgumentException(
                    "Đơn thuê không tồn tại.");
            }

            // Chỉ renter và owner được xem
            if (rental.RenterId != userId &&
                rental.Item.OwnerId != userId)
            {
                throw new UnauthorizedAccessException();
            }

            var reports = await _unitOfWork.ConditionReports
                .BuildQuery(c => c.RentalId == rentalId)
                .Include(c => c.Images)
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
            var report = await _unitOfWork.ConditionReports
                .BuildQuery(c => c.Id == reportId)
                .Include(c => c.Images)
                .FirstAsync();

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
                    report.Id,

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
