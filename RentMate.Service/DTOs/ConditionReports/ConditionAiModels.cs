using RentMate.Core.Enums;

namespace RentMate.Service.DTOs.ConditionReports
{
    // Một ảnh biên bản đã đọc thành byte để gửi cho AI
    public record ReportImageFile(byte[] Content, string MediaType);

    // Thông tin gửi cho AI.
    // - BeforeRental (chủ đồ lúc giao): so với ảnh tin đăng để biết có đúng món không, ghi khuyết điểm có sẵn.
    // - RenterReceived (người thuê lúc nhận): so với ảnh chủ đồ chụp lúc giao + ảnh tin đăng.
    // - AfterRental (chủ đồ lúc nhận lại): so với ảnh lúc người thuê nhận, tìm hư hỏng mới, gợi ý trừ cọc.
    public class ConditionAiRequest
    {
        public ConditionReportType Mode { get; set; }

        public string ItemName { get; set; } = string.Empty;
        public string ReportedCondition { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal DepositAmount { get; set; }

        public List<ReportImageFile> Images { get; set; } = new();

        // Ảnh của biên bản trước đó để so sánh
        public List<ReportImageFile> ReferenceImages { get; set; } = new();
        public string? ReferenceSummary { get; set; }

        // Ảnh lúc đăng tin (để phát hiện giao sai món)
        public List<ReportImageFile> ListingImages { get; set; } = new();
    }

    // Kết quả AI trả về (đúng theo JSON schema gửi kèm yêu cầu)
    public class ConditionAiResult
    {
        public string Summary { get; set; } = string.Empty;

        // Cùng thang với ItemCondition: 1 Mới, 2 Như mới, 3 Tốt, 4 Khá, 5 Hư hỏng
        public int SuggestedCondition { get; set; }

        public List<string> Damages { get; set; } = new();

        public bool NewDamageFound { get; set; }

        // Có phải cùng một món với ảnh tin đăng / ảnh lúc giao không
        public bool SameItem { get; set; } = true;

        // Phần trăm tiền cọc AI gợi ý trừ (chỉ có ý nghĩa với biên bản lúc nhận lại)
        public int SuggestedDeductionPercent { get; set; }
    }
}
