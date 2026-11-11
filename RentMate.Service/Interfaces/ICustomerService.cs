using RentMate.Core.ViewModels;

namespace RentMate.Service.Interfaces
{
    public interface ICustomerService
    {
        Task<CustomerListViewModel> SearchAsync(string? searchTerm, bool? isActive, int page = 1);

        Task<CustomerViewModel?> GetByIdAsync(string id);

        // Mật khẩu tạm gửi vào email của khách; trả về false nếu gửi email thất bại
        Task<bool> CreateAsync(CustomerViewModel model, string actorUserId, string ipAddress);

        Task UpdateAsync(CustomerViewModel model, string actorUserId, string ipAddress);

        // Mật khẩu tạm gửi vào email của khách; trả về false nếu gửi email thất bại
        Task<bool> ResetPasswordAsync(string id, string actorUserId, string ipAddress);

        Task<bool> SetActiveAsync(string id, bool isActive, string actorUserId, string ipAddress);
    }
}
