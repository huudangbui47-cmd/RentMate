namespace RentMate.Core.ViewModels
{
    // Trang dịch câu chữ của một ngôn ngữ: lọc, phân trang, danh sách câu
    public class TranslationListViewModel
    {
        public int LanguageId { get; set; }

        public string LanguageCode { get; set; } = string.Empty;

        public string LanguageName { get; set; } = string.Empty;

        public string? SearchTerm { get; set; }

        // "" tất cả, "missing" chưa dịch, "machine" AI dịch chưa xem lại
        public string? Filter { get; set; }

        public int Page { get; set; } = 1;

        public int PageSize { get; set; } = 20;

        public int TotalCount { get; set; }

        public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);

        public int MissingCount { get; set; }

        public int MachineCount { get; set; }

        public List<TranslationItemViewModel> Items { get; set; } = new();
    }
}
