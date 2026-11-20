using RentMate.Core.Enums;
using RentMate.Service.DTOs.ConditionReports;

namespace RentMate.Service.Interfaces
{
    public interface IConditionReportService
    {
        // imageUrls: ảnh đã lưu; images: nội dung ảnh để AI xem;
        // referenceImages: ảnh biên bản trước để so sánh; listingImages: ảnh tin đăng (phát hiện giao sai món)
        Task<ConditionReportDto> CreateAsync(
            int rentalId,
            CreateConditionReportDto dto,
            string userId,
            List<string> imageUrls,
            List<ReportImageFile> images,
            List<ReportImageFile> referenceImages,
            List<ReportImageFile> listingImages);

        // Đường dẫn ảnh cần đọc để AI so sánh khi lập biên bản loại reportType
        Task<(List<string> ReportImages, List<string> ListingImages)> GetReferenceImageUrlsAsync(int rentalId, ConditionReportType reportType);

        Task<List<ConditionReportDto>> GetByRentalAsync(
            int rentalId,
            string userId);
    }
}
