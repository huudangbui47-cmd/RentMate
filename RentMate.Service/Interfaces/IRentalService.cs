using RentMate.Core.Enums;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Rentals;

namespace RentMate.Service.Interfaces
{
    public interface IRentalService
    {
        // API
        Task<RentalDto> CreateAsync(
            CreateRentalDto dto,
            string renterId);

        Task<List<RentalDto>> GetMyRentalsAsync(
            string userId);

        Task<RentalDto?> GetByIdAsync(
            int rentalId,
            string userId);

        Task<bool> ApproveAsync(
            int rentalId,
            string ownerId);

        Task<bool> RejectAsync(
            int rentalId,
            string ownerId);

        Task<bool> PickupAsync(
            int rentalId,
            string ownerId);

        Task<bool> ReturnAsync(
            int rentalId,
            string renterId);

        Task<bool> CompleteAsync(
            int rentalId,
            string ownerId);

        // Trang quản trị
        Task<RentalListViewModel> SearchAsync(string? searchTerm, RentalStatus? status, int page = 1);

        Task<RentalDetailsViewModel?> GetDetailsAsync(int id);
    }
}
