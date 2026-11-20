using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RentMate.Service.DTOs;
using RentMate.Service.DTOs.Shipping;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    // Gọi API Giao Hàng Nhanh (https://api.ghn.vn). Dùng chung một tài khoản cửa hàng GHN của RentMate,
    // địa chỉ lấy hàng là địa chỉ cửa hàng đã khai trên GHN.
    public class GhnShippingService : IShippingService
    {
        private readonly HttpClient _http;
        private readonly GhnSettings _settings;
        private readonly ILogger<GhnShippingService> _logger;

        public GhnShippingService(HttpClient http, IOptions<GhnSettings> options, ILogger<GhnShippingService> logger)
        {
            _http = http;
            _settings = options.Value;
            _logger = logger;
        }

        public bool IsEnabled => !string.IsNullOrWhiteSpace(_settings.Token) && _settings.ShopId > 0;

        public async Task<List<AddressOptionDto>> GetProvincesAsync() =>
            ToOptions(await SendAsync(HttpMethod.Get, "/master-data/province", null, false), "ProvinceID", "ProvinceName");

        public async Task<List<AddressOptionDto>> GetDistrictsAsync(int provinceId) =>
            ToOptions(await SendAsync(HttpMethod.Post, "/master-data/district", new { province_id = provinceId }, false), "DistrictID", "DistrictName");

        public async Task<List<AddressOptionDto>> GetWardsAsync(int districtId) =>
            ToOptions(await SendAsync(HttpMethod.Post, "/master-data/ward", new { district_id = districtId }, false), "WardCode", "WardName");

        public async Task<ShipmentResult> CreateOrderAsync(ShipmentRequest r)
        {
            var body = new Dictionary<string, object?>
            {
                ["payment_type_id"] = 1, // RentMate (người gửi) trả phí ship
                ["required_note"] = "CHOXEMHANGKHONGTHU",
                ["client_order_code"] = r.ClientOrderCode,
                ["to_name"] = r.ToName,
                ["to_phone"] = r.ToPhone,
                ["to_address"] = r.ToAddress,
                ["to_ward_code"] = r.ToWardCode,
                ["to_district_id"] = r.ToDistrictId,
                ["cod_amount"] = 0,
                ["content"] = r.Content,
                ["note"] = r.Note,
                ["weight"] = r.WeightGram,
                ["length"] = 20,
                ["width"] = 20,
                ["height"] = 20,
                ["service_type_id"] = 2, // hàng nhẹ
                ["items"] = new[]
                {
                    new Dictionary<string, object> { ["name"] = r.Content, ["quantity"] = 1, ["weight"] = r.WeightGram }
                }
            };

            var data = await SendAsync(HttpMethod.Post, "/v2/shipping-order/create", body, true);

            return new ShipmentResult
            {
                OrderCode = data.GetProperty("order_code").GetString() ?? string.Empty,
                Fee = data.TryGetProperty("total_fee", out var fee) && fee.ValueKind == JsonValueKind.Number ? fee.GetDecimal() : 0,
                ExpectedDeliveryAt = ReadDate(data, "expected_delivery_time")
            };
        }

        public async Task<ShipmentTracking> GetTrackingAsync(string orderCode)
        {
            var data = await SendAsync(HttpMethod.Post, "/v2/shipping-order/detail", new { order_code = orderCode }, false);

            var tracking = new ShipmentTracking
            {
                Status = data.TryGetProperty("status", out var s) ? s.GetString() ?? "" : ""
            };

            if (data.TryGetProperty("log", out var logs) && logs.ValueKind == JsonValueKind.Array)
            {
                foreach (var log in logs.EnumerateArray())
                {
                    var time = ReadDate(log, "updated_date");

                    if (time != null && log.TryGetProperty("status", out var st))
                        tracking.Logs.Add((st.GetString() ?? "", time.Value));
                }
            }

            return tracking;
        }

        public async Task TryCancelOrderAsync(string orderCode)
        {
            try
            {
                await SendAsync(HttpMethod.Post, "/v2/switch-status/cancel", new { order_codes = new[] { orderCode } }, true);
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning("Không hủy được vận đơn GHN {OrderCode}: {Message}", orderCode, ex.Message);
            }
        }

        // Trạng thái GHN -> câu tiếng Việt cho người dùng
        public static string StatusText(string status) => status switch
        {
            "ready_to_pick" => "Người cho thuê đang chuẩn bị hàng, chờ GHN đến lấy",
            "picking" => "Shipper GHN đang đến lấy hàng",
            "money_collect_picking" => "Shipper đang tương tác với người gửi",
            "picked" => "GHN đã lấy hàng",
            "storing" => "Hàng đã nhập kho GHN",
            "transporting" => "Đang luân chuyển giữa các kho",
            "sorting" => "Đang phân loại tại kho",
            "delivering" => "Shipper đang giao hàng cho bạn",
            "money_collect_delivering" => "Shipper đang tương tác với người nhận",
            "delivered" => "Giao hàng thành công",
            "delivery_fail" => "Giao hàng không thành công",
            "waiting_to_return" => "Chờ giao lại",
            "return" or "return_transporting" or "return_sorting" or "returning" => "Đang hoàn hàng về người gửi",
            "return_fail" => "Hoàn hàng không thành công",
            "returned" => "Đã hoàn hàng về người gửi",
            "cancel" => "Vận đơn đã hủy",
            "exception" => "Đơn hàng gặp sự cố",
            "damage" => "Hàng bị hư hỏng khi vận chuyển",
            "lost" => "Hàng bị thất lạc",
            _ => status
        };

        private async Task<JsonElement> SendAsync(HttpMethod method, string path, object? body, bool withShop)
        {
            if (!IsEnabled)
                throw new InvalidOperationException("Chưa bật giao hàng GHN, vui lòng chọn nhận đồ trực tiếp.");

            using var request = new HttpRequestMessage(method, _settings.BaseUrl.TrimEnd('/') + path);
            request.Headers.Add("Token", _settings.Token);

            if (withShop)
                request.Headers.Add("ShopId", _settings.ShopId.ToString());

            if (body != null)
                request.Content = JsonContent.Create(body);

            string text;
            HttpResponseMessage response;

            try
            {
                response = await _http.SendAsync(request);
                text = await response.Content.ReadAsStringAsync();
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
            {
                _logger.LogError(ex, "Không gọi được GHN {Path}", path);
                throw new InvalidOperationException("Không kết nối được GHN, vui lòng thử lại sau.");
            }

            JsonElement root;

            try
            {
                using var doc = JsonDocument.Parse(text);
                root = doc.RootElement.Clone();
            }
            catch (JsonException)
            {
                _logger.LogError("GHN {Path} trả về {Status}: {Body}", path, response.StatusCode, text);
                throw new InvalidOperationException("GHN trả về dữ liệu không đọc được.");
            }

            bool ok = response.IsSuccessStatusCode &&
                (!root.TryGetProperty("code", out var code) || code.ValueKind != JsonValueKind.Number || code.GetInt32() == 200);

            if (!ok)
            {
                string? message = null;

                if (root.TryGetProperty("code_message_value", out var vi) && vi.ValueKind == JsonValueKind.String)
                    message = vi.GetString();

                if (string.IsNullOrWhiteSpace(message) && root.TryGetProperty("message", out var m) && m.ValueKind == JsonValueKind.String)
                    message = m.GetString();

                _logger.LogWarning("GHN {Path} báo lỗi: {Body}", path, text);
                throw new InvalidOperationException($"GHN báo lỗi: {message ?? response.StatusCode.ToString()}");
            }

            return root.TryGetProperty("data", out var data) ? data : default;
        }

        private static List<AddressOptionDto> ToOptions(JsonElement data, string idName, string nameName)
        {
            if (data.ValueKind != JsonValueKind.Array)
                return new List<AddressOptionDto>();

            return data.EnumerateArray()
                .Where(e => e.TryGetProperty(idName, out _) && e.TryGetProperty(nameName, out _))
                .Select(e =>
                {
                    var id = e.GetProperty(idName);
                    return new AddressOptionDto
                    {
                        Id = id.ValueKind == JsonValueKind.Number ? id.GetRawText() : id.GetString() ?? "",
                        Name = e.GetProperty(nameName).GetString() ?? ""
                    };
                })
                .OrderBy(o => o.Name)
                .ToList();
        }

        private static DateTime? ReadDate(JsonElement element, string name) =>
            element.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String && DateTime.TryParse(v.GetString(), null,
                System.Globalization.DateTimeStyles.AdjustToUniversal | System.Globalization.DateTimeStyles.AssumeUniversal, out var d)
                ? d
                : null;
    }
}
