using RentMate.Service.DTOs.ConditionReports;

namespace RentMate.Service.Interfaces
{
    public interface IConditionReportService
    {
        // imageUrls: ảnh đã lưu; images: nội dung ảnh để AI xem; beforeImages: ảnh lúc giao (chỉ có khi lập biên bản sau khi trả)
        Task<ConditionReportDto> CreateAsync(
            int rentalId,
            CreateConditionReportDto dto,
            string userId,
            List<string> imageUrls,
            List<ReportImageFile> images,
            List<ReportImageFile> beforeImages);

        Task<List<string>> GetBeforeImageUrlsAsync(int rentalId);

        Task<List<ConditionReportDto>> GetByRentalAsync(
            int rentalId,
            string userId);
    }
}
