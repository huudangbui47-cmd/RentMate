using RentMate.Api.DTOs.Items;

namespace RentMate.Api.Services.Interfaces
{
    public interface IItemService
    {
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
    }
}