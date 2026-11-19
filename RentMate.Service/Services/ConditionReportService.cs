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
        public const int MaxImages = 6;

        private readonly IUnitOfWork _unitOfWork;
        private readonly IConditionAiService _aiService;
        private readonly INotificationService _notificationService;

        public ConditionReportService(
            IUnitOfWork unitOfWork,
            IConditionAiService aiService,
            INotificationService notificationService)
        {
            _unitOfWork = unitOfWork;
            _aiService = aiService;
            _notificationService = notificationService;
        }

        // =========================
        // CREATE REPORT (chủ đồ chụp ảnh, AI đánh giá)
        // =========================
        public async Task<ConditionReportDto> CreateAsync(
            int rentalId,
            CreateConditionReportDto dto,
            string userId,
            List<string> imageUrls,
            List<ReportImageFile> images,
            List<ReportImageFile> beforeImages)
        {
            var rental = await _unitOfWork.Rentals
                .BuildQuery(r => r.Id == rentalId)
                .Include(r => r.Item)
                .FirstOrDefaultAsync();

            if (rental == null)
            {
                throw new ArgumentException("Đơn thuê không tồn tại.");
            }

            // Chủ đồ lập biên bản; người thuê xác nhận bằng nút "Đã nhận đồ" hoặc khiếu nại khi bị trừ cọc
            if (rental.Item.OwnerId != userId)
            {
                throw new UnauthorizedAccessException("Chỉ chủ đồ mới lập được biên bản.");
            }

            if (!Enum.IsDefined(typeof(ConditionReportType), dto.ReportType))
            {
                throw new ArgumentException("Loại biên bản không hợp lệ.");
            }

            if (!Enum.IsDefined(typeof(ItemCondition), dto.Condition))
            {
                throw new ArgumentException("Tình trạng đồ không hợp lệ.");
            }

            if (imageUrls.Count == 0)
            {
                throw new ArgumentException("Cần chụp ít nhất 1 ảnh món đồ.");
            }

            if (imageUrls.Count > MaxImages)
            {
                throw new ArgumentException($"Mỗi biên bản tối đa {MaxImages} ảnh.");
            }

            // Không cho tạo trùng Before/After
            var alreadyExists = await _unitOfWork.ConditionReports
                .BuildQuery(c => c.RentalId == rentalId && c.ReportType == dto.ReportType)
                .AnyAsync();

            if (alreadyExists)
            {
                throw new InvalidOperationException("Biên bản này đã được lập rồi.");
            }

            bool isAfter = dto.ReportType == ConditionReportType.AfterRental;

            if (!isAfter &&
                rental.Status != RentalStatus.Approved &&
                rental.Status != RentalStatus.WaitingForPickup)
            {
                throw new InvalidOperationException(
                    "Biên bản lúc giao chỉ lập được sau khi duyệt và trước khi người thuê nhận đồ.");
            }

            if (isAfter && rental.Status != RentalStatus.Returned)
            {
                throw new InvalidOperationException(
                    "Biên bản lúc nhận lại chỉ lập được khi người thuê đã trả đồ.");
            }

            // AI xem ảnh. Lỗi hoặc chưa bật thì vẫn lưu biên bản, chỉ thiếu phần AI.
            string? beforeSummary = null;

            if (isAfter)
            {
                beforeSummary = await _unitOfWork.ConditionReports
                    .BuildQuery(c => c.RentalId == rentalId && c.ReportType == ConditionReportType.BeforeRental)
                    .Select(c => c.AiSummary ?? c.Description)
                    .FirstOrDefaultAsync();
            }

            var ai = await _aiService.AnalyzeAsync(new ConditionAiRequest
            {
                ItemName = rental.Item.ItemName,
                ReportedCondition = ConditionAiService.ConditionName((int)dto.Condition),
                Description = dto.Description,
                DepositAmount = rental.DepositAmount,
                Images = images,
                BeforeImages = isAfter ? beforeImages : new List<ReportImageFile>(),
                BeforeSummary = isAfter ? beforeSummary ?? "" : null
            });

            var report = new ConditionReport
            {
                RentalId = rentalId,
                CreatedByUserId = userId,
                ReportType = dto.ReportType,
                Condition = dto.Condition,
                Description = dto.Description?.Trim(),
                CreatedAt = DateTime.UtcNow
            };

            if (ai != null)
            {
                report.AiSummary = Truncate(ai.Summary, 1000);
                report.AiDamages = ai.Damages.Count == 0 ? null : Truncate(string.Join("\n", ai.Damages), 2000);
                report.AiSuggestedCondition = (ItemCondition)ai.SuggestedCondition;
                report.AiAnalyzedAt = DateTime.UtcNow;

                if (isAfter)
                {
                    report.AiNewDamageFound = ai.NewDamageFound;
                    // Làm tròn tới nghìn đồng, không vượt tiền cọc
                    report.AiSuggestedDeduction = Math.Min(
                        rental.DepositAmount,
                        Math.Round(rental.DepositAmount * ai.SuggestedDeductionPercent / 100m / 1000m, 0) * 1000m);
                }
            }

            foreach (var imageUrl in imageUrls)
            {
                report.Images.Add(new ConditionReportImage
                {
                    ImageUrl = imageUrl,
                    CreatedAt = DateTime.UtcNow
                });
            }

            await _unitOfWork.ConditionReports.AddAsync(report);

            await _notificationService.AddAsync(rental.RenterId, NotificationType.System,
                isAfter ? "Chủ đồ đã lập biên bản nhận lại" : "Chủ đồ đã lập biên bản lúc giao",
                isAfter
                    ? $"Đơn #{rental.Id} '{rental.Item.ItemName}': chủ đồ đã chụp ảnh lúc nhận lại đồ. Vào Đơn thuê để xem."
                    : $"Đơn #{rental.Id} '{rental.Item.ItemName}': xem ảnh biên bản, nhận đồ đúng như vậy thì bấm Đã nhận đồ.");

            await _unitOfWork.SaveChangesAsync();

            return await GetDtoAsync(report.Id);
        }

        public async Task<List<string>> GetBeforeImageUrlsAsync(int rentalId)
        {
            return await _unitOfWork.ConditionReports
                .BuildQuery(c => c.RentalId == rentalId && c.ReportType == ConditionReportType.BeforeRental)
                .SelectMany(c => c.Images.Select(i => i.ImageUrl))
                .ToListAsync();
        }

        // =========================
        // GET REPORTS OF RENTAL
        // =========================
        public async Task<List<ConditionReportDto>> GetByRentalAsync(
            int rentalId,
            string userId)
        {
            var rental = await _unitOfWork.Rentals
                .BuildQuery(r => r.Id == rentalId)
                .Include(r => r.Item)
                .FirstOrDefaultAsync();

            if (rental == null)
            {
                throw new ArgumentException("Đơn thuê không tồn tại.");
            }

            // Chỉ renter và owner được xem
            if (rental.RenterId != userId && rental.Item.OwnerId != userId)
            {
                throw new UnauthorizedAccessException();
            }

            var reports = await _unitOfWork.ConditionReports
                .BuildQuery(c => c.RentalId == rentalId)
                .Include(c => c.Images)
                .OrderBy(c => c.CreatedAt)
                .ToListAsync();

            return reports.Select(ToDto).ToList();
        }

        private async Task<ConditionReportDto> GetDtoAsync(int reportId)
        {
            var report = await _unitOfWork.ConditionReports
                .BuildQuery(c => c.Id == reportId)
                .Include(c => c.Images)
                .FirstAsync();

            return ToDto(report);
        }

        private static string Truncate(string text, int max) =>
            text.Length > max ? text[..max] : text;

        private static ConditionReportDto ToDto(ConditionReport report)
        {
            return new ConditionReportDto
            {
                ConditionReportId = report.Id,
                RentalId = report.RentalId,
                ReportType = report.ReportType.ToString(),
                Condition = report.Condition.ToString(),
                Description = report.Description,
                CreatedByUserId = report.CreatedByUserId,
                CreatedAt = report.CreatedAt,
                ImageUrls = report.Images.Select(i => i.ImageUrl).ToList(),

                AiSummary = report.AiSummary,
                AiDamages = string.IsNullOrWhiteSpace(report.AiDamages)
                    ? new List<string>()
                    : report.AiDamages.Split('\n', StringSplitOptions.RemoveEmptyEntries).ToList(),
                AiSuggestedCondition = report.AiSuggestedCondition?.ToString(),
                AiNewDamageFound = report.AiNewDamageFound,
                AiSuggestedDeduction = report.AiSuggestedDeduction
            };
        }
    }
}
