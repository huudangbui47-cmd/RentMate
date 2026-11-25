using System.Reflection;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Localization;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    // Đa ngôn ngữ cho app: câu tiếng Việt trong code là khóa (TextResource), bản dịch lưu trong TextTranslation.
    // Quản trị viên thêm ngôn ngữ, sửa bản dịch, dịch nháp bằng AI trên trang quản trị; app tải về khi mở.
    public class LocalizationService : ILocalizationService
    {
        private const int PageSize = 20;

        // Mỗi lần bấm "Dịch bằng AI" dịch tối đa ngần này câu, chia nhỏ mỗi lần gọi AI để không quá lâu
        private const int AutoTranslateLimit = 150;
        private const int AutoTranslateBatch = 50;

        // File câu chữ gốc của app kèm bản tiếng Anh (Resources/app-texts.en.json, nhúng vào dll)
        private const string DefaultTextsResource = "RentMate.Service.Resources.app-texts.en.json";

        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuditLogService _auditLogService;
        private readonly ITranslationAiService _aiService;

        public LocalizationService(IUnitOfWork unitOfWork, IAuditLogService auditLogService, ITranslationAiService aiService)
        {
            _unitOfWork = unitOfWork;
            _auditLogService = auditLogService;
            _aiService = aiService;
        }

        // =========================
        // API
        // =========================

        public async Task<List<LanguageDto>> GetLanguagesAsync()
        {
            return await _unitOfWork.AppLanguages
                .BuildQuery(l => l.IsActive)
                .OrderBy(l => l.SortOrder).ThenBy(l => l.Name)
                .Select(l => new LanguageDto
                {
                    Code = l.Code,
                    Name = l.Name,
                    Flag = l.Flag,
                    Version = l.UpdatedAt.Ticks
                })
                .ToListAsync();
        }

        public async Task<TranslationPackDto?> GetPackAsync(string code)
        {
            var language = await _unitOfWork.AppLanguages
                .BuildQuery(l => l.Code == code && l.IsActive)
                .FirstOrDefaultAsync();

            if (language == null)
                return null;

            var texts = await _unitOfWork.TextTranslations
                .BuildQuery(t => t.LanguageId == language.Id)
                .Select(t => new { t.TextResource.Key, t.Value })
                .ToListAsync();

            return new TranslationPackDto
            {
                Code = language.Code,
                Version = language.UpdatedAt.Ticks,
                Texts = texts.ToDictionary(t => t.Key, t => t.Value)
            };
        }

        // =========================
        // TRANG QUẢN TRỊ: NGÔN NGỮ
        // =========================

        public async Task<List<LanguageViewModel>> GetLanguagesForManagementAsync()
        {
            int total = await _unitOfWork.TextResources.BuildQuery(t => true).CountAsync();

            return await _unitOfWork.AppLanguages
                .BuildQuery(l => true)
                .OrderBy(l => l.SortOrder).ThenBy(l => l.Name)
                .Select(l => new LanguageViewModel
                {
                    Id = l.Id,
                    Code = l.Code,
                    Name = l.Name,
                    Flag = l.Flag,
                    SortOrder = l.SortOrder,
                    IsActive = l.IsActive,
                    UpdatedAt = l.UpdatedAt,
                    TotalTexts = total,
                    TranslatedCount = l.Translations.Count,
                    MachineCount = l.Translations.Count(t => t.IsMachineTranslated)
                })
                .ToListAsync();
        }

        public async Task<LanguageViewModel?> GetLanguageAsync(int id)
        {
            return (await GetLanguagesForManagementAsync()).FirstOrDefault(l => l.Id == id);
        }

        public async Task CreateLanguageAsync(LanguageViewModel model, string actorUserId, string ipAddress)
        {
            string code = model.Code.Trim().ToLowerInvariant();

            if (code == "vi")
                throw new InvalidOperationException("Tiếng Việt là ngôn ngữ gốc của app, không cần thêm.");

            if (await _unitOfWork.AppLanguages.BuildQuery(l => l.Code == code).AnyAsync())
                throw new InvalidOperationException($"Ngôn ngữ có mã {code} đã tồn tại.");

            var language = new AppLanguage
            {
                Code = code,
                Name = model.Name.Trim(),
                Flag = string.IsNullOrWhiteSpace(model.Flag) ? null : model.Flag.Trim(),
                SortOrder = model.SortOrder,
                // Ngôn ngữ mới chưa có bản dịch: ẩn trước, dịch xong mới bật cho người dùng thấy
                IsActive = false,
                UpdatedAt = DateTime.UtcNow
            };

            await _unitOfWork.AppLanguages.AddAsync(language);

            await _auditLogService.RecordAsync("CreateLanguage", "AppLanguage", null,
                $"Thêm ngôn ngữ {language.Name} ({language.Code})", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task UpdateLanguageAsync(LanguageViewModel model, string actorUserId, string ipAddress)
        {
            var language = await _unitOfWork.AppLanguages.GetByIdAsync(model.Id)
                ?? throw new InvalidOperationException("Ngôn ngữ không tồn tại.");

            string name = model.Name.Trim();
            string? flag = string.IsNullOrWhiteSpace(model.Flag) ? null : model.Flag.Trim();

            if (language.Name == name && language.Flag == flag && language.SortOrder == model.SortOrder)
                return;

            language.Name = name;
            language.Flag = flag;
            language.SortOrder = model.SortOrder;
            language.UpdatedAt = DateTime.UtcNow;

            await _auditLogService.RecordAsync("UpdateLanguage", "AppLanguage", language.Id.ToString(),
                $"Cập nhật ngôn ngữ {language.Name} ({language.Code})", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task SetLanguageActiveAsync(int id, bool isActive, string actorUserId, string ipAddress)
        {
            var language = await _unitOfWork.AppLanguages.GetByIdAsync(id)
                ?? throw new InvalidOperationException("Ngôn ngữ không tồn tại.");

            if (language.IsActive == isActive)
                throw new InvalidOperationException(isActive ? "Ngôn ngữ này đã được hiện trước đó." : "Ngôn ngữ này đã được ẩn trước đó.");

            if (isActive && !await _unitOfWork.TextTranslations.BuildQuery(t => t.LanguageId == id).AnyAsync())
                throw new InvalidOperationException("Ngôn ngữ chưa có câu nào được dịch. Hãy dịch trước rồi mới hiện trên app.");

            language.IsActive = isActive;
            language.UpdatedAt = DateTime.UtcNow;

            await _auditLogService.RecordAsync("ToggleLanguage", "AppLanguage", language.Id.ToString(),
                $"{(isActive ? "Hiện" : "Ẩn")} ngôn ngữ {language.Name} ({language.Code}) trên app", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        // =========================
        // TRANG QUẢN TRỊ: BẢN DỊCH
        // =========================

        public async Task<TranslationListViewModel?> SearchTextsAsync(int languageId, string? searchTerm, string? filter, int page = 1)
        {
            var language = await _unitOfWork.AppLanguages.BuildQuery(l => l.Id == languageId).FirstOrDefaultAsync();

            if (language == null)
                return null;

            var query = _unitOfWork.TextResources.BuildQuery(t => true);

            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                string term = searchTerm.Trim();
                query = query.Where(t => t.Key.Contains(term) || t.Translations.Any(x => x.LanguageId == languageId && x.Value.Contains(term)));
            }

            if (filter == "missing")
                query = query.Where(t => !t.Translations.Any(x => x.LanguageId == languageId));
            else if (filter == "machine")
                query = query.Where(t => t.Translations.Any(x => x.LanguageId == languageId && x.IsMachineTranslated));

            int totalCount = await query.CountAsync();
            int totalPages = Math.Max(1, (int)Math.Ceiling((double)totalCount / PageSize));
            page = Math.Clamp(page, 1, totalPages);

            var items = await query
                .OrderBy(t => t.Id)
                .Skip((page - 1) * PageSize)
                .Take(PageSize)
                .Select(t => new TranslationItemViewModel
                {
                    TextResourceId = t.Id,
                    Key = t.Key,
                    Note = t.Note,
                    Value = t.Translations.Where(x => x.LanguageId == languageId).Select(x => x.Value).FirstOrDefault(),
                    IsMachineTranslated = t.Translations.Any(x => x.LanguageId == languageId && x.IsMachineTranslated)
                })
                .ToListAsync();

            return new TranslationListViewModel
            {
                LanguageId = language.Id,
                LanguageCode = language.Code,
                LanguageName = language.Name,
                SearchTerm = searchTerm,
                Filter = filter,
                Page = page,
                PageSize = PageSize,
                TotalCount = totalCount,
                MissingCount = await _unitOfWork.TextResources.BuildQuery(t => !t.Translations.Any(x => x.LanguageId == languageId)).CountAsync(),
                MachineCount = await _unitOfWork.TextTranslations.BuildQuery(x => x.LanguageId == languageId && x.IsMachineTranslated).CountAsync(),
                Items = items
            };
        }

        // Lưu các câu trên một trang: câu sửa thì cập nhật (thành "đã dịch", hết đánh dấu AI), xóa trắng thì bỏ bản dịch.
        // Câu không đổi nhưng đang là "AI dịch" và được gửi lên cùng dấu xác nhận thì cũng coi như đã xem lại.
        public async Task<int> SaveTranslationsAsync(int languageId, List<TranslationEditViewModel> items, string actorUserId, string ipAddress)
        {
            var language = await _unitOfWork.AppLanguages.GetByIdAsync(languageId)
                ?? throw new InvalidOperationException("Ngôn ngữ không tồn tại.");

            var ids = items.Select(i => i.TextResourceId).Distinct().ToList();

            var sources = await _unitOfWork.TextResources
                .BuildQuery(t => ids.Contains(t.Id))
                .ToDictionaryAsync(t => t.Id, t => t.Key);

            var existingIds = await _unitOfWork.TextTranslations
                .BuildQuery(t => t.LanguageId == languageId && ids.Contains(t.TextResourceId))
                .Select(t => t.Id)
                .ToListAsync();

            var existing = (await _unitOfWork.TextTranslations.GetByIdsAsync(existingIds))
                .ToDictionary(t => t.TextResourceId);

            int changed = 0;

            foreach (var item in items)
            {
                if (!sources.TryGetValue(item.TextResourceId, out var source))
                    continue;

                string value = (item.Value ?? string.Empty).Trim();
                string original = (item.OriginalValue ?? string.Empty).Trim();
                existing.TryGetValue(item.TextResourceId, out var translation);

                if (value == original)
                    continue;

                if (value.Length > 2000)
                    throw new InvalidOperationException($"Bản dịch của câu \"{Short(source)}\" dài quá 2000 ký tự.");

                if (value.Length > 0 && !TranslationAiService.SamePlaceholders(source, value))
                    throw new InvalidOperationException(
                        $"Bản dịch của câu \"{Short(source)}\" phải giữ đúng các chỗ trống {{0}}, {{1}}... như câu gốc. Chưa lưu trang này, hãy sửa rồi lưu lại.");

                if (value.Length == 0)
                {
                    if (translation != null)
                        _unitOfWork.TextTranslations.Delete(translation);
                }
                else if (translation == null)
                {
                    await _unitOfWork.TextTranslations.AddAsync(new TextTranslation
                    {
                        TextResourceId = item.TextResourceId,
                        LanguageId = languageId,
                        Value = value,
                        IsMachineTranslated = false,
                        UpdatedAt = DateTime.UtcNow
                    });
                }
                else
                {
                    translation.Value = value;
                    translation.IsMachineTranslated = false;
                    translation.UpdatedAt = DateTime.UtcNow;
                }

                changed++;
            }

            if (changed == 0)
                return 0;

            language.UpdatedAt = DateTime.UtcNow;

            await _auditLogService.RecordAsync("UpdateTranslations", "AppLanguage", language.Id.ToString(),
                $"Sửa {changed} bản dịch tiếng {language.Name} ({language.Code})", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();

            return changed;
        }

        // Thêm câu mới (vd. thông báo lỗi từ server muốn dịch). Câu phải viết đúng từng chữ như app hiển thị.
        public async Task CreateTextAsync(string key, string? note, string actorUserId, string ipAddress)
        {
            key = (key ?? string.Empty).Trim();

            if (key.Length == 0)
                throw new InvalidOperationException("Vui lòng nhập câu tiếng Việt.");

            if (key.Length > 450)
                throw new InvalidOperationException("Câu tối đa 450 ký tự.");

            if (await _unitOfWork.TextResources.BuildQuery(t => t.Key == key).AnyAsync())
                throw new InvalidOperationException("Câu này đã có trong danh sách.");

            await _unitOfWork.TextResources.AddAsync(new TextResource
            {
                Key = key,
                Note = string.IsNullOrWhiteSpace(note) ? null : note.Trim(),
                CreatedAt = DateTime.UtcNow
            });

            await _auditLogService.RecordAsync("CreateText", "TextResource", null,
                $"Thêm câu cần dịch: {Short(key)}", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        // Xóa câu không còn dùng; bản dịch của nó ở mọi ngôn ngữ bị xóa theo
        public async Task DeleteTextAsync(int id, string actorUserId, string ipAddress)
        {
            var text = await _unitOfWork.TextResources.GetByIdAsync(id)
                ?? throw new InvalidOperationException("Câu này không còn tồn tại.");

            var languageIds = await _unitOfWork.TextTranslations
                .BuildQuery(t => t.TextResourceId == id)
                .Select(t => t.LanguageId)
                .ToListAsync();

            foreach (var language in await _unitOfWork.AppLanguages.GetByIdsAsync(languageIds))
                language.UpdatedAt = DateTime.UtcNow;

            _unitOfWork.TextResources.Delete(text);

            await _auditLogService.RecordAsync("DeleteText", "TextResource", id.ToString(),
                $"Xóa câu: {Short(text.Key)}", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        // Nạp câu chữ gốc của app và bản tiếng Anh có sẵn. Chỉ thêm cái còn thiếu, không ghi đè bản dịch admin đã sửa.
        public async Task<(int NewTexts, int NewTranslations)> ImportDefaultsAsync(string actorUserId, string ipAddress)
        {
            var defaults = ReadDefaultTexts();

            var existingKeys = await _unitOfWork.TextResources
                .BuildQuery(t => true)
                .ToDictionaryAsync(t => t.Key, t => t.Id);

            var english = await _unitOfWork.AppLanguages.BuildQuery(l => l.Code == "en").FirstOrDefaultAsync();
            AppLanguage? newEnglish = null;

            if (english == null)
            {
                newEnglish = new AppLanguage { Code = "en", Name = "English", Flag = "🇬🇧", SortOrder = 1, IsActive = true, UpdatedAt = DateTime.UtcNow };
                await _unitOfWork.AppLanguages.AddAsync(newEnglish);
            }
            else
            {
                (await _unitOfWork.AppLanguages.GetByIdAsync(english.Id))!.UpdatedAt = DateTime.UtcNow;
            }

            var translatedIds = english == null
                ? new HashSet<int>()
                : (await _unitOfWork.TextTranslations
                    .BuildQuery(t => t.LanguageId == english.Id)
                    .Select(t => t.TextResourceId)
                    .ToListAsync()).ToHashSet();

            int newTexts = 0, newTranslations = 0;

            foreach (var (key, value) in defaults)
            {
                if (key.Length > 450)
                    continue;

                TextResource? resource = null;

                if (!existingKeys.TryGetValue(key, out int resourceId))
                {
                    resource = new TextResource { Key = key, CreatedAt = DateTime.UtcNow };
                    await _unitOfWork.TextResources.AddAsync(resource);
                    newTexts++;
                }
                else if (translatedIds.Contains(resourceId))
                {
                    continue;
                }

                var translation = new TextTranslation { Value = value, IsMachineTranslated = false, UpdatedAt = DateTime.UtcNow };

                if (resource != null)
                    translation.TextResource = resource;
                else
                    translation.TextResourceId = resourceId;

                if (newEnglish != null)
                    translation.Language = newEnglish;
                else
                    translation.LanguageId = english!.Id;

                await _unitOfWork.TextTranslations.AddAsync(translation);
                newTranslations++;
            }

            if (newTexts == 0 && newTranslations == 0 && newEnglish == null)
                return (0, 0);

            await _auditLogService.RecordAsync("ImportTexts", "TextResource", null,
                $"Nạp câu chữ gốc của app: {newTexts} câu mới, {newTranslations} bản dịch tiếng Anh", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();

            return (newTexts, newTranslations);
        }

        // =========================
        // DỊCH BẰNG AI
        // =========================

        public bool IsAutoTranslateEnabled => _aiService.IsEnabled;

        public async Task<int> AutoTranslateAsync(int languageId, string actorUserId, string ipAddress)
        {
            if (!_aiService.IsEnabled)
                throw new InvalidOperationException("Chưa cấu hình khóa AI (mục \"Ai\" trong appsettings của AdminSite).");

            var language = await _unitOfWork.AppLanguages.GetByIdAsync(languageId)
                ?? throw new InvalidOperationException("Ngôn ngữ không tồn tại.");

            var missing = await _unitOfWork.TextResources
                .BuildQuery(t => !t.Translations.Any(x => x.LanguageId == languageId))
                .OrderBy(t => t.Id)
                .Take(AutoTranslateLimit)
                .Select(t => new TranslationAiItem(t.Id, t.Key, t.Note))
                .ToListAsync();

            if (missing.Count == 0)
                throw new InvalidOperationException("Mọi câu đều đã được dịch.");

            int added = 0;

            foreach (var batch in missing.Chunk(AutoTranslateBatch))
            {
                var translated = await _aiService.TranslateAsync(language.Code, language.Name, batch.ToList());

                foreach (var (id, value) in translated)
                {
                    await _unitOfWork.TextTranslations.AddAsync(new TextTranslation
                    {
                        TextResourceId = id,
                        LanguageId = languageId,
                        Value = value,
                        IsMachineTranslated = true,
                        UpdatedAt = DateTime.UtcNow
                    });
                    added++;
                }
            }

            if (added == 0)
                throw new InvalidOperationException("AI chưa dịch được câu nào. Kiểm tra khóa AI và số dư tài khoản Claude API rồi thử lại.");

            language.UpdatedAt = DateTime.UtcNow;

            await _auditLogService.RecordAsync("AutoTranslate", "AppLanguage", language.Id.ToString(),
                $"AI dịch {added} câu sang {language.Name} ({language.Code})", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();

            return added;
        }

        // =========================
        // HỖ TRỢ
        // =========================

        private static Dictionary<string, string> ReadDefaultTexts()
        {
            using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(DefaultTextsResource)
                ?? throw new InvalidOperationException("Không tìm thấy file câu chữ gốc của app.");

            return JsonSerializer.Deserialize<Dictionary<string, string>>(stream) ?? new();
        }

        private static string Short(string text) => text.Length <= 60 ? text : text[..57] + "...";
    }
}
