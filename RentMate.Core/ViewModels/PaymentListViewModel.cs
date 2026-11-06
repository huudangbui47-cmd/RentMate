using RentMate.Core.Enums;

namespace RentMate.Core.ViewModels
{
    public class PaymentListViewModel
    {
        public PaymentStatus? Status { get; set; }
        public PaymentType? PaymentType { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public decimal TotalPaidAmount { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 10;
        public int TotalCount { get; set; }
        public int TotalPages => Math.Max(1, (TotalCount + PageSize - 1) / PageSize);

        public List<PaymentViewModel> Payments { get; set; } = new();
    }
}
