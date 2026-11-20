using RentMate.Service.DTOs.Wallet;

namespace RentMate.Service.Interfaces
{
    // Nạp ví qua cổng VNPay (sandbox): tạo link thanh toán, xử lý kết quả VNPay gửi về
    public interface IVnPayService
    {
        bool IsEnabled { get; }

        Task<VnPayPaymentDto> CreatePaymentAsync(string userId, CreateVnPayPaymentDto dto, string ipAddress);

        // query: toàn bộ tham số vnp_* VNPay gửi về
        Task<VnPayCallbackResult> ProcessCallbackAsync(IDictionary<string, string> query);
    }
}
