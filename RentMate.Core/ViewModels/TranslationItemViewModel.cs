namespace RentMate.Core.ViewModels
{
    // Một câu trên trang dịch: câu gốc tiếng Việt và bản dịch hiện tại
    public class TranslationItemViewModel
    {
        public int TextResourceId { get; set; }

        public string Key { get; set; } = string.Empty;

        public string? Note { get; set; }

        public string? Value { get; set; }

        public bool IsMachineTranslated { get; set; }

        public string StatusText => string.IsNullOrEmpty(Value) ? "Chưa dịch" : IsMachineTranslated ? "AI dịch" : "Đã dịch";
    }
}
