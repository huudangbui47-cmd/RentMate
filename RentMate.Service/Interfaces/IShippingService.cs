using RentMate.Service.DTOs.Shipping;

namespace RentMate.Service.Interfaces
{
    // Giao hàng qua GHN. Lỗi từ GHN được đổi thành InvalidOperationException (tiếng Việt).
    public interface IShippingService
    {
        bool IsEnabled { get; }

        Task<List<AddressOptionDto>> GetProvincesAsync();

        Task<List<AddressOptionDto>> GetDistrictsAsync(int provinceId);

        Task<List<AddressOptionDto>> GetWardsAsync(int districtId);

        Task<ShipmentResult> CreateOrderAsync(ShipmentRequest request);

        Task<ShipmentTracking> GetTrackingAsync(string orderCode);

        // Hủy vận đơn khi đơn thuê bị hủy; lỗi chỉ ghi log, không chặn việc hủy đơn
        Task TryCancelOrderAsync(string orderCode);
    }
}
