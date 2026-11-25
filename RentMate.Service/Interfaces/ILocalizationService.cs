using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Localization;

namespace RentMate.Service.Interfaces
{
    public interface ILocalizationService
    {
        // API cho app
        Task<List<LanguageDto>> GetLanguagesAsync();
        Task<TranslationPackDto?> GetPackAsync(string code);

        // Trang quản trị: ngôn ngữ
        Task<List<LanguageViewModel>> GetLanguagesForManagementAsync();
        Task<LanguageViewModel?> GetLanguageAsync(int id);
        Task CreateLanguageAsync(LanguageViewModel model, string actorUserId, string ipAddress);
        Task UpdateLanguageAsync(LanguageViewModel model, string actorUserId, string ipAddress);
        Task SetLanguageActiveAsync(int id, bool isActive, string actorUserId, string ipAddress);

        // Trang quản trị: câu chữ và bản dịch
        Task<TranslationListViewModel?> SearchTextsAsync(int languageId, string? searchTerm, string? filter, int page = 1);
        Task<int> SaveTranslationsAsync(int languageId, List<TranslationEditViewModel> items, string actorUserId, string ipAddress);
        Task CreateTextAsync(string key, string? note, string actorUserId, string ipAddress);
        Task DeleteTextAsync(int id, string actorUserId, string ipAddress);
        Task<(int NewTexts, int NewTranslations)> ImportDefaultsAsync(string actorUserId, string ipAddress);

        // Dịch tự động bằng AI các câu chưa dịch; trả về số câu đã dịch
        bool IsAutoTranslateEnabled { get; }
        Task<int> AutoTranslateAsync(int languageId, string actorUserId, string ipAddress);
    }
}
