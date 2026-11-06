using RentMate.Core.ViewModels;

namespace RentMate.Service.Interfaces
{
    public interface IAccountService
    {
        Task<UserListViewModel> SearchAsync(string? searchTerm, bool? isActive, int page = 1);

        Task<UserListItemViewModel?> GetByIdAsync(string userId);

        Task CreateAsync(UserCreateViewModel model, string actorUserId, string ipAddress);

        Task UpdateUserAsync(UserEditViewModel model, string actorUserId, string ipAddress);

        Task<bool> ToggleActiveAsync(string id, string actorUserId, string ipAddress);

        Task DeleteAsync(string id, string actorUserId, string ipAddress);

        Task UpdateProfileAsync(string userId, AccountProfileViewModel model, string ipAddress);

        Task<string?> UpdateAvatarAsync(string userId, string? avatarUrl, string ipAddress);

        Task ChangePasswordAsync(string userId, string oldPassword, string newPassword, string ipAddress);
    }
}
