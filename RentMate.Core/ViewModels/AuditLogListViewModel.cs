namespace RentMate.Core.ViewModels
{
    public class AuditLogListViewModel
    {
        public string? UserId { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 10;
        public int TotalCount { get; set; }
        public int TotalPages => Math.Max(1, (TotalCount + PageSize - 1) / PageSize);

        public List<AuditLogItemViewModel> Logs { get; set; } = new();
        public List<AuditLogUserViewModel> Users { get; set; } = new();
    }
}
