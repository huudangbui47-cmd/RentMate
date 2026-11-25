using System.ComponentModel.DataAnnotations;

namespace RentMate.Service.DTOs.Wallet
{
    // App xin link thanh toán VNPay.
    // Có RentalId: nạp đúng số còn thiếu để trả đơn đó (server tự tính), thanh toán xong tự trả tiền đơn.
    // Không có RentalId: nạp Amount vào ví.
    public class CreateVnPayPaymentDto
    {
        // Giới hạn số tiền theo cài đặt hệ thống, service kiểm tra
        [Range(1, double.MaxValue, ErrorMessage = "Số tiền phải lớn hơn 0.")]
        public decimal? Amount { get; set; }

        public int? RentalId { get; set; }
    }

    public class VnPayPaymentDto
    {
        public string PaymentUrl { get; set; } = string.Empty;

        public string Code { get; set; } = string.Empty;

        public decimal Amount { get; set; }
    }

    // Kết quả xử lý khi VNPay báo về (trang trả về hoặc IPN)
    public class VnPayCallbackResult
    {
        public bool Success { get; set; }

        public string Message { get; set; } = string.Empty;

        // Mã trả lời cho IPN theo tài liệu VNPay: 00 thành công, 01 không thấy đơn, 02 đã xử lý, 04 sai số tiền, 97 sai chữ ký
        public string RspCode { get; set; } = "00";
    }
}
