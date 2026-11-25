using RentMate.Core.Enums;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Rentals;
using RentMate.Service.DTOs.Shipping;

namespace RentMate.Service.Interfaces
{
    public interface IRentalService
    {
        // API
        Task<RentalDto> CreateAsync(
            CreateRentalDto dto,
            string renterId);

        Task<List<RentalDto>> GetMyRentalsAsync(
            string userId);

        Task<RentalDto?> GetByIdAsync(
            int rentalId,
            string userId);

        Task<bool> ApproveAsync(
            int rentalId,
            string ownerId);

        Task<bool> RejectAsync(
            int rentalId,
            string ownerId);

        // Người thuê xác nhận đã nhận đồ (đồng ý biên bản lúc giao)
        Task<bool> PickupAsync(
            int rentalId,
            string renterId);

        Task<bool> ReturnAsync(
            int rentalId,
            string renterId);

        // Chủ đồ hoàn tất (kèm số tiền trừ cọc nếu có); người thuê tự hoàn tất khi chủ đồ quá hạn kiểm tra
        Task<bool> CompleteAsync(
            int rentalId,
            string userId,
            decimal damageAmount,
            string? damageNote);

        Task<bool> AcceptDamageAsync(int rentalId, string renterId);

        Task<bool> DisputeAsync(int rentalId, string renterId, string reason);

        // Trang quản trị: phân xử khiếu nại
        Task ResolveDisputeAsync(int rentalId, decimal damageAmount, string? note, string adminId, string ipAddress);

        // Trang quản trị
        Task<RentalListViewModel> SearchAsync(string? searchTerm, RentalStatus? status, int page = 1);

        Task<RentalDetailsViewModel?> GetDetailsAsync(int id);
        Task<bool> PayAsync(int rentalId, string renterId);
        Task<bool> CancelAsync(int rentalId, string userId, string? reason = null);

        // Giao hàng GHN: chủ đồ tạo vận đơn; hai bên xem dòng thời gian giao nhận
        Task<bool> CreateShipmentAsync(int rentalId, string ownerId, int weightGram);

        Task<ShippingTrackingDto?> GetShippingAsync(int rentalId, string userId);

        // Đồ bị xóa/ẩn/tạm ngưng: từ chối hoặc hủy các đơn chưa giao, hoàn tiền đơn đã thanh toán, báo người thuê.
        // Chưa SaveChanges: hàm gọi tự lưu cùng lúc với việc đổi trạng thái đồ.
        Task<int> CloseOpenRentalsAsync(int itemId, string itemName, string reason);
    }
}
