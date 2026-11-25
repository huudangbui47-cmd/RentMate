using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Banners;

namespace RentMate.Service.Interfaces
{
    public interface IBannerService
    {
        // API
        Task<List<BannerDto>> GetActiveAsync();

        // Trang quản trị
        Task<List<BannerViewModel>> GetAllForManagementAsync();
        Task CreateAsync(string imageUrl, string? title, string actorUserId, string ipAddress);
        Task SetActiveAsync(int id, bool isActive, string actorUserId, string ipAddress);
        Task MoveAsync(int id, bool up, string actorUserId, string ipAddress);

        // Trả đường dẫn ảnh để nơi gọi xóa file sau khi đã xóa dòng trong database
        Task<string> DeleteAsync(int id, string actorUserId, string ipAddress);
    }
}
