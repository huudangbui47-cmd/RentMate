using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Categories;

namespace RentMate.Service.Interfaces
{
    public interface ICategoryService
    {
        // API
        Task<List<CategoryDto>> GetAllAsync();
        Task<CategoryDto?> GetByIdAsync(int id);

        // Trang quản trị
        Task<List<CategoryViewModel>> GetAllForManagementAsync();
        Task<List<CategoryOptionViewModel>> GetParentOptionsAsync();
        Task CreateAsync(CategoryViewModel model, string actorUserId, string ipAddress);
        Task UpdateAsync(CategoryViewModel model, string actorUserId, string ipAddress);
        Task SetActiveAsync(int id, bool isActive, string actorUserId, string ipAddress);
        Task DeleteAsync(int id, string actorUserId, string ipAddress);
    }
}
