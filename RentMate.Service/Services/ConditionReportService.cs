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
        private readonly IConditionAiService _aiService;
        private readonly INotificationService _notificationService;
        private readonly ISystemSettingService _settingService;

        public ConditionReportService(
            IUnitOfWork unitOfWork,
            IConditionAiService aiService,
            INotificationService notificationService,
            ISystemSettingService settingService)
        {
            _settingService = settingService;
            _unitOfWork = unitOfWork;
            _aiService = aiService;
            _notificationService = notificationService;
        }

        // =========================
        // CREATE REPORT
        // Chủ đồ: lúc giao (BeforeRental) và lúc nhận lại (AfterRental).
        // Người thuê: lúc nhận đồ (RenterReceived), bắt buộc trước khi bấm "Đã nhận đồ".
        // =========================
        public async Task<ConditionReportDto> CreateAsync(
            int rentalId,
            CreateConditionReportDto dto,
            string userId,
            List<string> imageUrls,
            List<ReportImageFile> images,
            List<ReportImageFile> referenceImages,
            List<ReportImageFile> listingImages)
        {
            var rental = await _unitOfWork.Rentals
                .BuildQuery(r => r.Id == rentalId)
                .Include(r => r.Item)
                .FirstOrDefaultAsync();

            if (rental == null)
            {
                throw new ArgumentException("Đơn thuê không tồn tại.");
            }

            if (!Enum.IsDefined(typeof(ConditionReportType), dto.ReportType))
            {
                throw new ArgumentException("Loại biên bản không hợp lệ.");
            }

            var type = dto.ReportType;
            bool isOwner = rental.Item.OwnerId == userId;
            bool isRenter = rental.RenterId == userId;

            if (type == ConditionReportType.RenterReceived ? !isRenter : !isOwner)
            {
                throw new UnauthorizedAccessException(type == ConditionReportType.RenterReceived
                    ? "Chỉ người thuê mới lập được biên bản lúc nhận đồ."
                    : "Chỉ chủ đồ mới lập được biên bản này.");
            }

            if (!Enum.IsDefined(typeof(ItemCondition), dto.Condition))
            {
                throw new ArgumentException("Tình trạng đồ không hợp lệ.");
            }

            if (imageUrls.Count == 0)
            {
                throw new ArgumentException("Cần chụp ít nhất 1 ảnh món đồ.");
            }

            // Số ảnh tối đa theo cài đặt hệ thống
            int maxImages = (await _settingService.GetAsync()).MaxReportImages;

            if (imageUrls.Count > maxImages)
            {
                throw new ArgumentException($"Mỗi biên bản tối đa {maxImages} ảnh.");
            }

            var existingTypes = await _unitOfWork.ConditionReports
                .BuildQuery(c => c.RentalId == rentalId)
                .Select(c => c.ReportType)
                .ToListAsync();

            if (existingTypes.Contains(type))
            {
                throw new InvalidOperationException("Biên bản này đã được lập rồi.");
            }

            switch (type)
            {
                case ConditionReportType.BeforeRental
                    when rental.Status != RentalStatus.Approved && rental.Status != RentalStatus.WaitingForPickup:
                    throw new InvalidOperationException(
                        "Biên bản lúc giao chỉ lập được sau khi duyệt và trước khi người thuê nhận đồ.");

                case ConditionReportType.RenterReceived when rental.Status != RentalStatus.WaitingForPickup:
                    throw new InvalidOperationException(
                        "Biên bản lúc nhận chỉ lập được khi đơn đã thanh toán và bạn chưa bấm Đã nhận đồ.");

                case ConditionReportType.RenterReceived when !existingTypes.Contains(ConditionReportType.BeforeRental):
                    throw new InvalidOperationException(
                        "Chủ đồ chưa chụp ảnh biên bản lúc giao. Đừng nhận đồ khi chưa có biên bản này.");

                case ConditionReportType.AfterRental when rental.Status != RentalStatus.Returned:
                    throw new InvalidOperationException(
                        "Biên bản lúc nhận lại chỉ lập được khi người thuê đã trả đồ.");
            }

            // Mốc so sánh: người thuê so với ảnh lúc giao; chủ đồ nhận lại so với ảnh lúc người thuê nhận
            string? referenceSummary = type switch
            {
                ConditionReportType.RenterReceived => await GetSummaryAsync(rentalId, ConditionReportType.BeforeRental),
                ConditionReportType.AfterRental =>
                    await GetSummaryAsync(rentalId, ConditionReportType.RenterReceived)
                    ?? await GetSummaryAsync(rentalId, ConditionReportType.BeforeRental),
                _ => null
            };

            // AI xem ảnh. Lỗi hoặc chưa bật thì vẫn lưu biên bản, chỉ thiếu phần AI.
            var ai = await _aiService.AnalyzeAsync(new ConditionAiRequest
            {
                Mode = type,
                ItemName = rental.Item.ItemName,
                ReportedCondition = ConditionAiService.ConditionName((int)dto.Condition),
                Description = dto.Description,
                DepositAmount = rental.DepositAmount,
                Images = images,
                ReferenceImages = referenceImages,
                ReferenceSummary = referenceSummary,
                ListingImages = listingImages
            });

            var report = new ConditionReport
            {
                RentalId = rentalId,
                CreatedByUserId = userId,
                ReportType = type,
                Condition = dto.Condition,
                Description = dto.Description?.Trim(),
                CreatedAt = DateTime.UtcNow
            };

            if (ai != null)
            {
                report.AiSummary = Truncate(ai.Summary, 1000);
                report.AiDamages = ai.Damages.Count == 0 ? null : Truncate(string.Join("\n", ai.Damages), 2000);
                report.AiSuggestedCondition = (ItemCondition)ai.SuggestedCondition;
                report.AiSameItem = ai.SameItem;
                report.AiAnalyzedAt = DateTime.UtcNow;

                if (type != ConditionReportType.BeforeRental)
                {
                    report.AiNewDamageFound = ai.NewDamageFound;
                }

                if (type == ConditionReportType.AfterRental)
                {
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

            string itemText = $"Đơn #{rental.Id} '{rental.Item.ItemName}'";
            string warning = report.AiSameItem == false ? " AI thấy đồ trong ảnh có thể KHÁC món đã đăng, hãy kiểm tra kỹ." : "";

            switch (type)
            {
                case ConditionReportType.BeforeRental:
                    await _notificationService.AddAsync(rental.RenterId, NotificationType.System,
                        "Chủ đồ đã chụp biên bản lúc giao",
                        $"{itemText}: khi nhận đồ, chụp ảnh đối chiếu rồi mới bấm Đã nhận đồ.{warning}");
                    break;

                case ConditionReportType.RenterReceived:
                    await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.System,
                        "Người thuê đã chụp ảnh lúc nhận đồ",
                        $"{itemText}: người thuê đã chụp ảnh đối chiếu lúc nhận.{warning}");
                    break;

                default:
                    await _notificationService.AddAsync(rental.RenterId, NotificationType.System,
                        "Chủ đồ đã lập biên bản nhận lại",
                        $"{itemText}: chủ đồ đã chụp ảnh lúc nhận lại đồ. Vào Đơn thuê để xem.");
                    break;
            }

            await _unitOfWork.SaveChangesAsync();

            return await GetDtoAsync(report.Id);
        }

        public async Task<(List<string> ReportImages, List<string> ListingImages)> GetReferenceImageUrlsAsync(
            int rentalId, ConditionReportType reportType)
        {
            // Mốc so sánh theo loại biên bản đang lập
            ConditionReportType? referenceType = reportType switch
            {
                ConditionReportType.RenterReceived => ConditionReportType.BeforeRental,
                ConditionReportType.AfterRental => ConditionReportType.RenterReceived,
                _ => null
            };

            var reportImages = new List<string>();

            if (referenceType != null)
            {
                reportImages = await GetReportImagesAsync(rentalId, referenceType.Value);

                // Đơn cũ chưa có biên bản người thuê thì so với ảnh lúc giao
                if (reportImages.Count == 0 && reportType == ConditionReportType.AfterRental)
                {
                    reportImages = await GetReportImagesAsync(rentalId, ConditionReportType.BeforeRental);
                }
            }

            // Ảnh tin đăng chỉ cần khi giao/nhận (kiểm tra đúng món), tối đa 3 ảnh cho đỡ tốn
            var listingImages = new List<string>();

            if (reportType != ConditionReportType.AfterRental)
            {
                var itemId = await _unitOfWork.Rentals
                    .BuildQuery(r => r.Id == rentalId)
                    .Select(r => r.ItemId)
                    .FirstOrDefaultAsync();

                listingImages = await _unitOfWork.Items
                    .BuildQuery(i => i.Id == itemId)
                    .SelectMany(i => i.Images.OrderByDescending(img => img.IsPrimary).Select(img => img.ImageUrl))
                    .Take(3)
                    .ToListAsync();
            }

            return (reportImages, listingImages);
        }

        private Task<List<string>> GetReportImagesAsync(int rentalId, ConditionReportType type) =>
            _unitOfWork.ConditionReports
                .BuildQuery(c => c.RentalId == rentalId && c.ReportType == type)
                .SelectMany(c => c.Images.Select(i => i.ImageUrl))
                .ToListAsync();

        private Task<string?> GetSummaryAsync(int rentalId, ConditionReportType type) =>
            _unitOfWork.ConditionReports
                .BuildQuery(c => c.RentalId == rentalId && c.ReportType == type)
                .Select(c => c.AiSummary ?? c.Description)
                .FirstOrDefaultAsync();

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
                AiSameItem = report.AiSameItem,
                AiSuggestedDeduction = report.AiSuggestedDeduction
            };
        }
    }
}
