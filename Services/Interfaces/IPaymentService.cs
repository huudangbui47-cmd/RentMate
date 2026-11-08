using RentMate.Api.DTOs.Payments;

namespace RentMate.Api.Services.Interfaces
{
    public interface IPaymentService
    {
        Task<PaymentDto> PayAsync(
            int rentalId,
            PayPaymentDto dto,
            string userId);

        Task<List<PaymentDto>> GetByRentalAsync(
            int rentalId,
            string userId);
    }
}