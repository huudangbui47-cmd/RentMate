using System.Text.Json;
using Anthropic;
using Anthropic.Exceptions;
using Anthropic.Models.Beta;
using Anthropic.Models.Beta.Messages;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RentMate.Core.Enums;
using RentMate.Service.DTOs;
using RentMate.Service.DTOs.ConditionReports;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    // Gọi Claude xem ảnh biên bản: mô tả tình trạng lúc giao, so sánh ảnh lúc nhận lại để tìm hư hỏng mới.
    // AI chỉ gợi ý; chủ đồ, người thuê và quản trị viên quyết định cuối cùng.
    public class ConditionAiService : IConditionAiService
    {
        private const string SystemPrompt =
            "Bạn là chuyên viên kiểm tra tình trạng đồ cho thuê của ứng dụng RentMate (cho thuê đồ giữa người với người tại Việt Nam). " +
            "Bạn nhận ảnh chụp một món đồ và đưa ra đánh giá khách quan, dùng làm bằng chứng khi giao đồ và khi nhận lại đồ.\n" +
            "Nguyên tắc:\n" +
            "- Chỉ ghi nhận hư hỏng nhìn thấy rõ trong ảnh: trầy xước, móp, nứt vỡ, ố bẩn không lau được, thiếu bộ phận hoặc phụ kiện. Nêu vị trí và mức độ cụ thể.\n" +
            "- Khác biệt do ánh sáng, góc chụp, độ nét hay bụi lau được thì không phải hư hỏng.\n" +
            "- Ảnh mờ, thiếu góc hoặc không thấy rõ món đồ thì nói rõ trong phần tóm tắt, không đoán.\n" +
            "- Viết tiếng Việt, ngắn gọn, giọng trung lập. Đây chỉ là gợi ý; con người quyết định cuối cùng.";

        private static readonly string[] ConditionNames = { "Mới", "Như mới", "Tốt", "Khá", "Hư hỏng" };

        private readonly AiSettings _settings;
        private readonly ILogger<ConditionAiService> _logger;

        public ConditionAiService(IOptions<AiSettings> options, ILogger<ConditionAiService> logger)
        {
            _settings = options.Value;
            _logger = logger;
        }

        public bool IsEnabled => !string.IsNullOrWhiteSpace(_settings.ApiKey);

        public async Task<ConditionAiResult?> AnalyzeAsync(ConditionAiRequest request)
        {
            if (!IsEnabled || request.Images.Count == 0)
            {
                return null;
            }

            var content = new List<BetaContentBlockParam>();
            string info =
                $"Món đồ: {request.ItemName}. Người chụp ghi tình trạng: {request.ReportedCondition}. " +
                $"Ghi chú: {request.Description ?? "không có"}. Tiền cọc: {request.DepositAmount:N0} đ.\n";

            if (request.ListingImages.Count > 0)
            {
                content.Add(new BetaTextBlockParam { Text = "ẢNH TIN ĐĂNG – món đồ chủ đồ đăng cho thuê:" });
                content.AddRange(request.ListingImages.Select(ToImageBlock));
            }

            if (request.ReferenceImages.Count > 0)
            {
                content.Add(new BetaTextBlockParam
                {
                    Text = request.Mode == ConditionReportType.AfterRental
                        ? "ẢNH LÚC NGƯỜI THUÊ NHẬN ĐỒ (mốc so sánh):"
                        : "ẢNH CHỦ ĐỒ CHỤP LÚC GIAO (mốc so sánh):"
                });
                content.AddRange(request.ReferenceImages.Select(ToImageBlock));
            }

            if (!string.IsNullOrWhiteSpace(request.ReferenceSummary))
            {
                content.Add(new BetaTextBlockParam { Text = $"Đánh giá ở mốc so sánh: {request.ReferenceSummary}" });
            }

            content.Add(new BetaTextBlockParam
            {
                Text = request.Mode switch
                {
                    ConditionReportType.BeforeRental => "ẢNH CHỦ ĐỒ CHỤP LÚC GIAO CHO NGƯỜI THUÊ:",
                    ConditionReportType.RenterReceived => "ẢNH NGƯỜI THUÊ CHỤP LÚC NHẬN ĐỒ:",
                    _ => "ẢNH CHỦ ĐỒ CHỤP LÚC NHẬN LẠI ĐỒ:"
                }
            });
            content.AddRange(request.Images.Select(ToImageBlock));

            content.Add(new BetaTextBlockParam
            {
                Text = info + request.Mode switch
                {
                    ConditionReportType.BeforeRental =>
                        "Mô tả tình trạng hiện tại và liệt kê vào damages mọi khuyết điểm có sẵn để làm mốc. " +
                        "sameItem = false nếu đồ trong ảnh rõ ràng là món khác với ảnh tin đăng (khác loại, khác mẫu, khác màu), " +
                        "không có ảnh tin đăng thì true. newDamageFound = false, suggestedDeductionPercent = 0.",
                    ConditionReportType.RenterReceived =>
                        "Kiểm tra món người thuê nhận có đúng là món trong ảnh lúc giao và ảnh tin đăng không (sameItem). " +
                        "Liệt kê vào damages khuyết điểm đang có; newDamageFound = true nếu có hư hỏng hoặc thiếu phụ kiện " +
                        "mà ảnh lúc giao không có. suggestedDeductionPercent = 0.",
                    _ =>
                        "So sánh với mốc. Chỉ đưa vào damages những hư hỏng MỚI mà mốc không có. sameItem = false nếu món trả lại " +
                        "rõ ràng không phải món đã giao. suggestedDeductionPercent là phần trăm tiền cọc nên trừ để bù chi phí sửa " +
                        "ước tính: 0 nếu không có hư hỏng mới, 100 nếu hỏng nặng, mất hoặc trả sai món."
                }
            });

            try
            {
                var client = new AnthropicClient { ApiKey = _settings.ApiKey };

                var response = await client.Beta.Messages.Create(new MessageCreateParams
                {
                    Model = _settings.Model,
                    MaxTokens = 16000,
                    // Bị bộ lọc an toàn từ chối thì máy chủ tự chuyển sang model dự phòng phù hợp
                    Betas = [AnthropicBeta.ServerSideFallback2026_07_01],
                    Fallbacks = new Default(),
                    System = SystemPrompt,
                    OutputConfig = new BetaOutputConfig
                    {
                        Effort = Effort.Medium,
                        Format = new BetaJsonOutputFormat { Schema = ResultSchema() }
                    },
                    Messages = [new BetaUserMessageParam { Content = content }]
                });

                if (response.StopReason == "refusal")
                {
                    _logger.LogWarning("AI từ chối phân tích ảnh biên bản.");
                    return null;
                }

                var json = response.Content
                    .Select(b => b.Value)
                    .OfType<BetaTextBlock>()
                    .Select(t => t.Text)
                    .FirstOrDefault();

                if (string.IsNullOrWhiteSpace(json))
                {
                    return null;
                }

                var result = JsonSerializer.Deserialize<ConditionAiResult>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                if (result == null)
                {
                    return null;
                }

                result.SuggestedCondition = Math.Clamp(result.SuggestedCondition, 1, 5);
                result.SuggestedDeductionPercent = request.Mode == ConditionReportType.AfterRental ? Math.Clamp(result.SuggestedDeductionPercent, 0, 100) : 0;
                result.Damages = result.Damages.Where(d => !string.IsNullOrWhiteSpace(d)).Take(20).ToList();

                return result;
            }
            catch (AnthropicApiException ex)
            {
                _logger.LogError(ex, "Gọi AI phân tích biên bản bị lỗi.");
                return null;
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
            {
                _logger.LogError(ex, "Không đọc được kết quả AI phân tích biên bản.");
                return null;
            }
        }

        public static string ConditionName(int value) =>
            value >= 1 && value <= 5 ? ConditionNames[value - 1] : "Không rõ";

        private static BetaContentBlockParam ToImageBlock(ReportImageFile image) =>
            new BetaImageBlockParam
            {
                Source = new BetaBase64ImageSource
                {
                    Data = Convert.ToBase64String(image.Content),
                    MediaType = image.MediaType == "image/png" ? MediaType.ImagePng : MediaType.ImageJpeg
                }
            };

        private static Dictionary<string, JsonElement> ResultSchema() => new()
        {
            ["type"] = JsonSerializer.SerializeToElement("object"),
            ["additionalProperties"] = JsonSerializer.SerializeToElement(false),
            ["required"] = JsonSerializer.SerializeToElement(new[]
            {
                "summary", "suggestedCondition", "damages", "newDamageFound", "sameItem", "suggestedDeductionPercent"
            }),
            ["properties"] = JsonSerializer.SerializeToElement(new Dictionary<string, object>
            {
                ["summary"] = new { type = "string", description = "Tóm tắt tình trạng, 1-3 câu tiếng Việt" },
                ["suggestedCondition"] = new { type = "integer", description = "1 Mới, 2 Như mới, 3 Tốt, 4 Khá, 5 Hư hỏng" },
                ["damages"] = new { type = "array", items = new { type = "string" }, description = "Mỗi dòng một hư hỏng: vị trí và mức độ" },
                ["newDamageFound"] = new { type = "boolean", description = "Có hư hỏng mới so với mốc hay không" },
                ["sameItem"] = new { type = "boolean", description = "Có đúng là cùng một món với ảnh tin đăng / ảnh mốc không" },
                ["suggestedDeductionPercent"] = new { type = "integer", description = "Phần trăm tiền cọc gợi ý trừ, 0-100" }
            })
        };
    }
}
