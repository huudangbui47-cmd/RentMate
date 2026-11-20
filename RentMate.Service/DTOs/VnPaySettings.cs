namespace RentMate.Service.DTOs
{
    // Mục "VnPay" trong appsettings. TmnCode và HashSecret VNPay gửi qua email khi đăng ký sandbox.
    public class VnPaySettings
    {
        public string? TmnCode { get; set; }

        public string? HashSecret { get; set; }

        public string PaymentUrl { get; set; } = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";

        // VNPay chuyển trình duyệt về địa chỉ này sau khi thanh toán (máy ảo Android gọi Api qua 10.0.2.2)
        public string ReturnUrl { get; set; } = "http://10.0.2.2:5076/api/payments/vnpay-return";
    }
}
