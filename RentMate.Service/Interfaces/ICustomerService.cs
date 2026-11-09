using RentMate.Core.ViewModels;

namespace RentMate.Service.Interfaces
{
    public interface ICustomerService
    {
        Task<CustomerListViewModel> SearchAsync(string? searchTerm, bool? isActive, int page = 1);

        Task<CustomerViewModel?> GetByIdAsync(string id);

        // Trả về mật khẩu tạm để nhân viên báo cho khách
        Task<string> CreateAsync(CustomerViewModel model, string actorUserId, string ipAddress);

        Task UpdateAsync(CustomerViewModel model, string actorUserId, string ipAddress);

        Task<string> ResetPasswordAsync(string id, string actorUserId, string ipAddress);

        Task<bool> SetActiveAsync(string id, bool isActive, string actorUserId, string ipAddress);
    }
}
