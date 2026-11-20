using RentMate.Service.DTOs.Localization;

namespace RentMate.Service.Interfaces
{
    public interface ITranslationAiService
    {
        bool IsEnabled { get; }

        // Trả về bản dịch theo Id câu; câu AI dịch sai định dạng ({0}, {1}...) thì bỏ qua
        Task<Dictionary<int, string>> TranslateAsync(string languageCode, string languageName, List<TranslationAiItem> items);
    }
}
