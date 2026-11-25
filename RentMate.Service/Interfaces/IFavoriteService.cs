using RentMate.Service.DTOs.Items;

namespace RentMate.Service.Interfaces
{
    public interface IFavoriteService
    {
        // Đồ đã lưu của khách (chỉ đồ còn hiện trên app), mới lưu đứng đầu
        Task<List<ItemDto>> GetMineAsync(string userId);

        // Id các món đã lưu, app dùng để tô tim đen
        Task<List<int>> GetMyIdsAsync(string userId);

        // false nếu món đồ không tồn tại / không còn hiện trên app
        Task<bool> AddAsync(string userId, int itemId);

        Task RemoveAsync(string userId, int itemId);
    }
}
