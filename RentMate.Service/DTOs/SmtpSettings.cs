namespace RentMate.Service.DTOs
{
    // Cấu hình gửi email, đọc từ mục "Smtp" trong appsettings.
    // Để trống Host/Username thì không gửi thật mà ghi nội dung email ra console (tiện khi chạy ở máy dev).
    public class SmtpSettings
    {
        public string Host { get; set; } = string.Empty;
        public int Port { get; set; } = 587;
        public bool EnableSsl { get; set; } = true;
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string FromName { get; set; } = "RentMate";
    }
}
