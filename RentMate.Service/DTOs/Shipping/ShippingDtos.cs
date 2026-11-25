using System.ComponentModel.DataAnnotations;

namespace RentMate.Service.DTOs.Shipping
{
    // Một dòng trong danh sách tỉnh / quận / phường của GHN
    public class AddressOptionDto
    {
        public string Id { get; set; } = string.Empty;

        public string Name { get; set; } = string.Empty;
    }

    // Chủ đồ tạo đơn giao hàng
    public class CreateShipmentDto
    {
        // Khối lượng ước tính (gram) để GHN tính phí
        [Range(100, 30000, ErrorMessage = "Khối lượng từ 100 g đến 30 kg.")]
        public int WeightGram { get; set; } = 1000;
    }

    // Thông tin gửi sang GHN để tạo vận đơn
    public class ShipmentRequest
    {
        public string ClientOrderCode { get; set; } = string.Empty;
        public string ToName { get; set; } = string.Empty;
        public string ToPhone { get; set; } = string.Empty;
        public string ToAddress { get; set; } = string.Empty;
        public string ToWardCode { get; set; } = string.Empty;
        public int ToDistrictId { get; set; }
        public string Content { get; set; } = string.Empty;
        public string? Note { get; set; }
        public int WeightGram { get; set; }
    }

    public class ShipmentResult
    {
        public string OrderCode { get; set; } = string.Empty;
        public decimal Fee { get; set; }
        public DateTime? ExpectedDeliveryAt { get; set; }
    }

    // Các mốc GHN ghi lại (trạng thái + thời gian)
    public class ShipmentTracking
    {
        public string Status { get; set; } = string.Empty;
        public List<(string Status, DateTime Time)> Logs { get; set; } = new();
    }

    // Một bước trên dòng thời gian giao hàng của app
    public class ShippingStepDto
    {
        public string Title { get; set; } = string.Empty;
        public string? Detail { get; set; }
        public DateTime? Time { get; set; }
        public bool Done { get; set; }
    }

    public class ShippingTrackingDto
    {
        public string DeliveryMethod { get; set; } = string.Empty;
        public string? OrderCode { get; set; }
        public string? StatusText { get; set; }
        public decimal? ShippingFee { get; set; }
        public DateTime? ExpectedDeliveryAt { get; set; }
        public string? ShipToText { get; set; }

        // Không gọi được GHN lúc này thì vẫn trả các mốc của RentMate, kèm câu báo
        public string? Warning { get; set; }

        public List<ShippingStepDto> Steps { get; set; } = new();
    }
}
