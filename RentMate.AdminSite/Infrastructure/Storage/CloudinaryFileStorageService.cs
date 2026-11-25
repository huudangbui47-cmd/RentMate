using CloudinaryDotNet;
using CloudinaryDotNet.Actions;

namespace RentMate.AdminSite.Infrastructure.Storage
{
    // Giống Api: có mục "Cloudinary" trong appsettings thì ảnh quản trị tải lên (ảnh đại diện, banner trang chủ)
    // lưu lên Cloudinary, database chỉ lưu link https. Ảnh cũ "/uploads/..." hoặc "/shared/..." vẫn xóa được
    // nhờ chuyển cho LocalFileStorageService.
    public class CloudinaryFileStorageService : IFileStorageService
    {
        private readonly Cloudinary _cloudinary;
        private readonly string _cloudName;
        private readonly LocalFileStorageService _local;
        private readonly ILogger<CloudinaryFileStorageService> _logger;

        public CloudinaryFileStorageService(
            IConfiguration configuration,
            LocalFileStorageService local,
            ILogger<CloudinaryFileStorageService> logger)
        {
            _cloudName = configuration["Cloudinary:CloudName"]!;
            _cloudinary = new Cloudinary(new Account(
                _cloudName,
                configuration["Cloudinary:ApiKey"],
                configuration["Cloudinary:ApiSecret"]));
            _cloudinary.Api.Secure = true;
            _local = local;
            _logger = logger;
        }

        public string? ValidateImage(IFormFile? file, long maxSizeBytes = 2 * 1024 * 1024) =>
            _local.ValidateImage(file, maxSizeBytes);

        // "uploads/avatars" -> thư mục "rentmate/avatars" trên Cloudinary
        public Task<string> SaveAsync(IFormFile file, string folder) => UploadAsync(file, folder);

        // Ảnh cho app (banner): link https dùng được ở cả AdminSite và app, không cần thư mục dùng chung
        public Task<string> SaveSharedAsync(IFormFile file, string folder) => UploadAsync(file, folder);

        public void Delete(string? relativePath)
        {
            if (string.IsNullOrWhiteSpace(relativePath))
                return;

            string? publicId = PublicIdOf(relativePath);

            if (publicId == null)
            {
                _local.Delete(relativePath);
                return;
            }

            try
            {
                _cloudinary.Destroy(new DeletionParams(publicId));
            }
            catch (Exception ex)
            {
                // Xóa ảnh không được thì chỉ ghi log, không làm hỏng thao tác chính
                _logger.LogWarning(ex, "Không xóa được ảnh Cloudinary {PublicId}", publicId);
            }
        }

        private async Task<string> UploadAsync(IFormFile file, string folder)
        {
            string cloudFolder = "rentmate/" + folder.Trim('/', '\\').Replace("uploads/", "");

            await using var stream = file.OpenReadStream();

            var result = await _cloudinary.UploadAsync(new ImageUploadParams
            {
                File = new FileDescription(file.FileName, stream),
                Folder = cloudFolder,
                PublicId = Guid.NewGuid().ToString("N")
            });

            if (result.Error != null || result.SecureUrl == null)
            {
                throw new InvalidOperationException("Không tải được ảnh lên Cloudinary: " + result.Error?.Message);
            }

            return result.SecureUrl.ToString();
        }

        // https://res.cloudinary.com/{cloud}/image/upload/v123/rentmate/banners/abc.jpg -> "rentmate/banners/abc"
        // null nếu không phải ảnh trong tài khoản Cloudinary này
        private string? PublicIdOf(string url)
        {
            string prefix = $"https://res.cloudinary.com/{_cloudName}/image/upload/";

            if (!url.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                return null;

            var parts = url[prefix.Length..].Split('/').ToList();

            // Bỏ số phiên bản "v123..." đứng đầu
            if (parts.Count > 1 && parts[0].Length > 1 && parts[0][0] == 'v' && parts[0][1..].All(char.IsDigit))
                parts.RemoveAt(0);

            string path = string.Join('/', parts);
            int dot = path.LastIndexOf('.');

            return dot > 0 ? path[..dot] : path;
        }
    }
}
