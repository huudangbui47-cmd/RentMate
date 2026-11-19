using RentMate.Service.DTOs.ConditionReports;

namespace RentMate.Service.Interfaces
{
    public interface IConditionAiService
    {
        // Đã cấu hình ApiKey hay chưa
        bool IsEnabled { get; }

        // Trả null khi chưa bật AI hoặc gọi AI lỗi: biên bản vẫn được lưu, chỉ thiếu phần AI đánh giá
        Task<ConditionAiResult?> AnalyzeAsync(ConditionAiRequest request);
    }
}
