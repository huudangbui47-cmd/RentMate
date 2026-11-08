using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Categories;

namespace RentMate.Service.Interfaces
{
    public interface ICategoryService
    {
        // API
        Task<List<CategoryDto>> GetAllAsync();
        Task<CategoryDto?> GetByIdAsync(int id);
        Task<CategoryDto> CreateAsync(CreateCategoryDto dto);

        // Trang quản trị
        Task<List<CategoryViewModel>> GetAllForManagementAsync();
        Task CreateAsync(CategoryViewModel model, string actorUserId, string ipAddress);
        Task UpdateAsync(CategoryViewModel model, string actorUserId, string ipAddress);
        Task ToggleActiveAsync(int id, string actorUserId, string ipAddress);
        Task DeleteAsync(int id, string actorUserId, string ipAddress);
    }
}
