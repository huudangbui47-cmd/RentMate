using Microsoft.EntityFrameworkCore;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Banners;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class BannerService : IBannerService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuditLogService _auditLogService;

        public BannerService(IUnitOfWork unitOfWork, IAuditLogService auditLogService)
        {
            _unitOfWork = unitOfWork;
            _auditLogService = auditLogService;
        }

        // =========================
        // API
        // =========================

        public async Task<List<BannerDto>> GetActiveAsync()
        {
            return await _unitOfWork.Banners
                .BuildQuery(b => b.IsActive)
                .OrderBy(b => b.SortOrder)
                .ThenBy(b => b.Id)
                .Select(b => new BannerDto
                {
                    BannerId = b.Id,
                    ImageUrl = b.ImageUrl
                })
                .ToListAsync();
        }

        // =========================
        // TRANG QUẢN TRỊ
        // =========================

        public async Task<List<BannerViewModel>> GetAllForManagementAsync()
        {
            return await _unitOfWork.Banners
                .BuildQuery(b => true)
                .OrderBy(b => b.SortOrder)
                .ThenBy(b => b.Id)
                .Select(b => new BannerViewModel
                {
                    Id = b.Id,
                    ImageUrl = b.ImageUrl,
                    Title = b.Title,
                    SortOrder = b.SortOrder,
                    IsActive = b.IsActive,
                    CreatedAt = b.CreatedAt
                })
                .ToListAsync();
        }

        // Ảnh mới đứng cuối danh sách
        public async Task CreateAsync(string imageUrl, string? title, string actorUserId, string ipAddress)
        {
            if (string.IsNullOrWhiteSpace(imageUrl))
                throw new InvalidOperationException("Vui lòng chọn ảnh banner.");

            string? cleanTitle = string.IsNullOrWhiteSpace(title) ? null : title.Trim();

            if (cleanTitle?.Length > 100)
                throw new InvalidOperationException("Ghi chú tối đa 100 ký tự.");

            int lastOrder = await _unitOfWork.Banners
                .BuildQuery(b => true)
                .Select(b => (int?)b.SortOrder)
                .MaxAsync() ?? 0;

            var banner = new Banner
            {
                ImageUrl = imageUrl,
                Title = cleanTitle,
                SortOrder = lastOrder + 1,
                IsActive = true
            };

            await _unitOfWork.Banners.AddAsync(banner);

            await _auditLogService.RecordAsync(
                "CreateBanner",
                "Banner",
                null,
                cleanTitle == null ? "Thêm banner trang chủ" : $"Thêm banner trang chủ: {cleanTitle}",
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task SetActiveAsync(int id, bool isActive, string actorUserId, string ipAddress)
        {
            var banner = await _unitOfWork.Banners.GetByIdAsync(id)
                ?? throw new InvalidOperationException("Banner không tồn tại.");

            if (banner.IsActive == isActive)
                throw new InvalidOperationException(isActive ? "Banner này đã được hiện trước đó." : "Banner này đã được ẩn trước đó.");

            banner.IsActive = isActive;

            await _auditLogService.RecordAsync(
                "ToggleBanner",
                "Banner",
                banner.Id.ToString(),
                $"{(isActive ? "Hiện" : "Ẩn")} banner trang chủ{Describe(banner)}",
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        // Đổi chỗ với banner đứng ngay trước (up) hoặc ngay sau
        public async Task MoveAsync(int id, bool up, string actorUserId, string ipAddress)
        {
            var banner = await _unitOfWork.Banners.GetByIdAsync(id)
                ?? throw new InvalidOperationException("Banner không tồn tại.");

            var ordered = await _unitOfWork.Banners
                .BuildQuery(b => true)
                .OrderBy(b => b.SortOrder)
                .ThenBy(b => b.Id)
                .Select(b => b.Id)
                .ToListAsync();

            int index = ordered.IndexOf(id);
            int target = up ? index - 1 : index + 1;

            if (target < 0 || target >= ordered.Count)
                return;

            // Đánh lại số thứ tự 1..n để không bị trùng số giữa các banner
            (ordered[index], ordered[target]) = (ordered[target], ordered[index]);

            var banners = await _unitOfWork.Banners.GetByIdsAsync(ordered);

            foreach (var b in banners)
                b.SortOrder = ordered.IndexOf(b.Id) + 1;

            await _auditLogService.RecordAsync(
                "MoveBanner",
                "Banner",
                banner.Id.ToString(),
                $"Đưa banner{Describe(banner)} {(up ? "lên trước" : "xuống sau")}",
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task<string> DeleteAsync(int id, string actorUserId, string ipAddress)
        {
            var banner = await _unitOfWork.Banners.GetByIdAsync(id)
                ?? throw new InvalidOperationException("Banner không tồn tại.");

            _unitOfWork.Banners.Delete(banner);

            await _auditLogService.RecordAsync(
                "DeleteBanner",
                "Banner",
                banner.Id.ToString(),
                $"Xóa banner trang chủ{Describe(banner)}",
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();

            return banner.ImageUrl;
        }

        private static string Describe(Banner banner) =>
            banner.Title == null ? $" #{banner.Id}" : $": {banner.Title}";
    }
}
