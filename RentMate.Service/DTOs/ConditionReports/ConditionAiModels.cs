namespace RentMate.Service.DTOs.ConditionReports
{
    // Một ảnh biên bản đã đọc thành byte để gửi cho AI
    public record ReportImageFile(byte[] Content, string MediaType);

    // Thông tin gửi cho AI. BeforeImages chỉ có khi lập biên bản sau khi trả (để so sánh).
    public class ConditionAiRequest
    {
        public string ItemName { get; set; } = string.Empty;
        public string ReportedCondition { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal DepositAmount { get; set; }

        public List<ReportImageFile> Images { get; set; } = new();
        public List<ReportImageFile> BeforeImages { get; set; } = new();
        public string? BeforeSummary { get; set; }

        public bool IsAfterRental => BeforeImages.Count > 0 || BeforeSummary != null;
    }

    // Kết quả AI trả về (đúng theo JSON schema gửi kèm yêu cầu)
    public class ConditionAiResult
    {
        public string Summary { get; set; } = string.Empty;

        // Cùng thang với ItemCondition: 1 Mới, 2 Như mới, 3 Tốt, 4 Khá, 5 Hư hỏng
        public int SuggestedCondition { get; set; }

        public List<string> Damages { get; set; } = new();

        public bool NewDamageFound { get; set; }

        // Phần trăm tiền cọc AI gợi ý trừ (chỉ có ý nghĩa với biên bản sau khi trả)
        public int SuggestedDeductionPercent { get; set; }
    }
}
