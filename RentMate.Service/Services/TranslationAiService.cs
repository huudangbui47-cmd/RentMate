using System.Text.Json;
using System.Text.RegularExpressions;
using Anthropic;
using Anthropic.Exceptions;
using Anthropic.Models.Beta;
using Anthropic.Models.Beta.Messages;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RentMate.Service.DTOs;
using RentMate.Service.DTOs.Localization;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    // Dùng Claude dịch nháp câu chữ của app (mục "Ai" trong appsettings, cùng khóa với AI biên bản).
    // Bản dịch được đánh dấu "AI dịch" để quản trị viên xem lại.
    public class TranslationAiService : ITranslationAiService
    {
        private const string SystemPrompt =
            "Bạn dịch giao diện ứng dụng di động RentMate (cho thuê đồ giữa người với người tại Việt Nam) từ tiếng Việt sang ngôn ngữ được yêu cầu.\n" +
            "Quy tắc:\n" +
            "- Giữ nguyên các chỗ trống {0}, {1}, {2}... đúng số lượng; có thể đổi vị trí cho hợp ngữ pháp.\n" +
            "- Giữ nguyên ký tự xuống dòng, emoji, dấu ngoặc kép, mũi tên và tên riêng: RentMate, VNPay, GHN, Giao Hàng Nhanh, ATM, QR.\n" +
            "- Chữ trong ngoặc kép là tên nút trong app: dịch nhất quán giữa các câu.\n" +
            "- \"đ\" là đơn vị tiền Việt Nam đồng, giữ nguyên.\n" +
            "- Văn phong ngắn gọn, thân thiện như các ứng dụng phổ biến; nhãn nút ngắn.\n" +
            "- Chỉ trả về bản dịch, không giải thích.";

        private static readonly Regex Placeholder = new(@"\{\d+\}");

        private readonly AiSettings _settings;
        private readonly ILogger<TranslationAiService> _logger;

        public TranslationAiService(IOptions<AiSettings> options, ILogger<TranslationAiService> logger)
        {
            _settings = options.Value;
            _logger = logger;
        }

        public bool IsEnabled => !string.IsNullOrWhiteSpace(_settings.ApiKey);

        public async Task<Dictionary<int, string>> TranslateAsync(string languageCode, string languageName, List<TranslationAiItem> items)
        {
            var result = new Dictionary<int, string>();

            if (!IsEnabled || items.Count == 0)
                return result;

            string input = JsonSerializer.Serialize(
                items.Select(i => new { id = i.Id, text = i.Text, note = i.Note }),
                new JsonSerializerOptions { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping });

            try
            {
                var client = new AnthropicClient { ApiKey = _settings.ApiKey };

                var response = await client.Beta.Messages.Create(new MessageCreateParams
                {
                    Model = _settings.Model,
                    MaxTokens = 32000,
                    Betas = [AnthropicBeta.ServerSideFallback2026_07_01],
                    Fallbacks = new Default(),
                    System = SystemPrompt,
                    OutputConfig = new BetaOutputConfig
                    {
                        Effort = Effort.Low,
                        Format = new BetaJsonOutputFormat { Schema = ResultSchema() }
                    },
                    Messages =
                    [
                        new BetaUserMessageParam
                        {
                            Content = $"Dịch sang {languageName} (mã {languageCode}) từng câu dưới đây, giữ nguyên id:\n{input}"
                        }
                    ]
                });

                if (response.StopReason == "refusal")
                {
                    _logger.LogWarning("AI từ chối dịch câu chữ.");
                    return result;
                }

                var json = response.Content
                    .Select(b => b.Value)
                    .OfType<BetaTextBlock>()
                    .Select(t => t.Text)
                    .FirstOrDefault();

                if (string.IsNullOrWhiteSpace(json))
                    return result;

                var parsed = JsonSerializer.Deserialize<AiResult>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                var sources = items.ToDictionary(i => i.Id, i => i.Text);

                foreach (var t in parsed?.Translations ?? new())
                {
                    if (!sources.TryGetValue(t.Id, out var source) || string.IsNullOrWhiteSpace(t.Text))
                        continue;

                    // Bản dịch phải có đúng các chỗ trống {0}, {1}... như câu gốc, không thì app hiện sai số liệu
                    if (!SamePlaceholders(source, t.Text))
                        continue;

                    result[t.Id] = t.Text.Length > 2000 ? t.Text[..2000] : t.Text;
                }
            }
            catch (AnthropicApiException ex)
            {
                _logger.LogError(ex, "Gọi AI dịch câu chữ bị lỗi.");
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
            {
                _logger.LogError(ex, "Không đọc được kết quả AI dịch câu chữ.");
            }

            return result;
        }

        public static bool SamePlaceholders(string source, string translated) =>
            Placeholder.Matches(source).Select(m => m.Value).OrderBy(v => v)
                .SequenceEqual(Placeholder.Matches(translated).Select(m => m.Value).OrderBy(v => v));

        private sealed class AiResult
        {
            public List<AiTranslation> Translations { get; set; } = new();
        }

        private sealed class AiTranslation
        {
            public int Id { get; set; }
            public string Text { get; set; } = string.Empty;
        }

        private static Dictionary<string, JsonElement> ResultSchema() => new()
        {
            ["type"] = JsonSerializer.SerializeToElement("object"),
            ["additionalProperties"] = JsonSerializer.SerializeToElement(false),
            ["required"] = JsonSerializer.SerializeToElement(new[] { "translations" }),
            ["properties"] = JsonSerializer.SerializeToElement(new Dictionary<string, object>
            {
                ["translations"] = new
                {
                    type = "array",
                    items = new
                    {
                        type = "object",
                        additionalProperties = false,
                        required = new[] { "id", "text" },
                        properties = new Dictionary<string, object>
                        {
                            ["id"] = new { type = "integer" },
                            ["text"] = new { type = "string" }
                        }
                    }
                }
            })
        };
    }
}
