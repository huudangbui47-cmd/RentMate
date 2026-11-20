using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Settings;

namespace RentMate.Service.Interfaces
{
    public interface ISystemSettingService
    {
        // Nghiệp vụ và API
        Task<RentMateSettings> GetAsync();
        Task<PublicSettingsDto> GetPublicAsync();

        // Trang quản trị
        Task<List<SystemSettingViewModel>> GetAllForManagementAsync();
        Task UpdateAsync(Dictionary<string, string?> values, string actorUserId, string ipAddress);
    }
}
