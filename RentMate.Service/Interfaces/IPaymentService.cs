using RentMate.Core.Enums;
using RentMate.Core.ViewModels;

namespace RentMate.Service.Interfaces
{
    public interface IPaymentService
    {
        Task<PaymentListViewModel> SearchAsync(PaymentStatus? status, PaymentType? paymentType, DateTime? fromDate, DateTime? toDate, int page = 1);
    }
}
