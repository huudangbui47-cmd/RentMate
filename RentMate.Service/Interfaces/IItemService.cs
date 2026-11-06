using RentMate.Core.Enums;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Items;

namespace RentMate.Service.Interfaces
{
    public interface IItemService
    {
        // API
        Task<List<ItemDto>> GetAllAsync();

        Task<ItemDto?> GetByIdAsync(int id);

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

        // Trang quản trị
        Task<ItemListViewModel> SearchAsync(string? searchTerm, int? categoryId, ItemStatus? status, int page = 1);

        Task UpdateStatusAsync(int id, ItemStatus status, string actorUserId, string ipAddress);
    }
}
