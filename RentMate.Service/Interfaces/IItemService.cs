using RentMate.Core.Enums;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Items;

namespace RentMate.Service.Interfaces
{
    public interface IItemService
    {
        // API
        Task<List<ItemDto>> GetAllAsync();

        // viewerId: người đang xem; chủ đồ xem được cả đồ chưa duyệt của mình
        Task<ItemDto?> GetByIdAsync(int id, string? viewerId = null);

        Task<List<ItemDto>> GetMyItemsAsync(string ownerId);

        Task<ItemDto> CreateAsync(
            CreateItemDto dto,
            string ownerId);

        Task<bool> UpdateAsync(
            int id,
            UpdateItemDto dto,
            string ownerId);

        Task<bool> DeleteAsync(
            int id,
            string ownerId);

        // Ảnh: controller lưu/xóa file, service ghi DB
        Task<List<ItemImageDto>?> AddImagesAsync(int itemId, List<string> imageUrls, string ownerId);

        Task<string?> DeleteImageAsync(int itemId, int imageId, string ownerId);

        Task<bool> SetPrimaryImageAsync(int itemId, int imageId, string ownerId);

        // Trang quản trị
        Task<ItemListViewModel> SearchAsync(string? searchTerm, int? categoryId, ItemStatus? status, int page = 1);

        Task UpdateStatusAsync(int id, ItemStatus status, string actorUserId, string ipAddress);

        Task ApproveAsync(int id, string actorUserId, string ipAddress);

        Task RejectAsync(int id, string reason, string actorUserId, string ipAddress);
    }
}
