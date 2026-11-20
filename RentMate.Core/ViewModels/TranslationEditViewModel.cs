namespace RentMate.Core.ViewModels
{
    // Dữ liệu gửi lên khi bấm "Lưu" trên trang dịch (một dòng cho mỗi câu trên trang)
    public class TranslationEditViewModel
    {
        public int TextResourceId { get; set; }

        public string? Value { get; set; }

        // Giá trị lúc tải trang, để chỉ lưu những câu thật sự bị sửa
        public string? OriginalValue { get; set; }
    }
}
