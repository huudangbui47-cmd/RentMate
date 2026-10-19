using RentMate.Api.DTOs.Rentals;

namespace RentMate.Api.Services.Interfaces
{
    public interface IRentalService
    {
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
    }
}