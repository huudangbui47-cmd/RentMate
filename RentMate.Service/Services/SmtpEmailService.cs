using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RentMate.Service.DTOs;
using RentMate.Service.Interfaces;
using System.Net;
using System.Net.Mail;

namespace RentMate.Service.Services
{
    public class SmtpEmailService : IEmailService
    {
        private readonly SmtpSettings _settings;
        private readonly ILogger<SmtpEmailService> _logger;

        public SmtpEmailService(IOptions<SmtpSettings> options, ILogger<SmtpEmailService> logger)
        {
            _settings = options.Value;
            _logger = logger;
        }

        public async Task SendAsync(string toEmail, string subject, string htmlBody)
        {
            // Chưa cấu hình Smtp: ghi ra console để vẫn lấy được link khi chạy thử
            if (string.IsNullOrWhiteSpace(_settings.Host) || string.IsNullOrWhiteSpace(_settings.Username))
            {
                _logger.LogWarning(
                    "Chưa cấu hình Smtp nên KHÔNG gửi email thật.\nGửi tới: {ToEmail}\nTiêu đề: {Subject}\nNội dung:\n{Body}",
                    toEmail, subject, htmlBody);

                return;
            }

            using var message = new MailMessage
            {
                From = new MailAddress(_settings.Username, _settings.FromName),
                Subject = subject,
                Body = htmlBody,
                IsBodyHtml = true
            };

            message.To.Add(toEmail);

            using var client = new SmtpClient(_settings.Host, _settings.Port)
            {
                EnableSsl = _settings.EnableSsl,
                Credentials = new NetworkCredential(_settings.Username, _settings.Password)
            };

            try
            {
                await client.SendMailAsync(message);
            }
            catch (SmtpException ex)
            {
                _logger.LogError(ex, "Gửi email tới {ToEmail} thất bại.", toEmail);

                throw new InvalidOperationException("Hệ thống chưa gửi được email. Vui lòng thử lại sau hoặc liên hệ quản trị viên.");
            }
        }
    }
}
