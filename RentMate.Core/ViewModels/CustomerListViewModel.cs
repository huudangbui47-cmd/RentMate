namespace RentMate.Core.ViewModels
{
    public class CustomerListViewModel
    {
        public string? SearchTerm { get; set; }
        public bool? IsActive { get; set; }

        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 10;
        public int TotalCount { get; set; }
        public int TotalPages => Math.Max(1, (TotalCount + PageSize - 1) / PageSize);

        public List<CustomerViewModel> Customers { get; set; } = new();
    }
}
