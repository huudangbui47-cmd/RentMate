using RentMate.Core.Enums;

namespace RentMate.Core.ViewModels
{
    public class ItemListViewModel
    {
        public string? SearchTerm { get; set; }
        public int? CategoryId { get; set; }
        public ItemStatus? Status { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 10;
        public int TotalCount { get; set; }
        public int TotalPages => Math.Max(1, (TotalCount + PageSize - 1) / PageSize);

        public List<ItemListItemViewModel> Items { get; set; } = new();
        public List<CategoryOptionViewModel> Categories { get; set; } = new();
    }
}
