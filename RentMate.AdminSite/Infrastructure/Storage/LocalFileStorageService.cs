namespace RentMate.AdminSite.Infrastructure.Storage
{
    public class LocalFileStorageService : IFileStorageService
    {
        private static readonly HashSet<string> AllowedImageExtensions =
            new(StringComparer.OrdinalIgnoreCase) { ".jpg", ".jpeg", ".png" };

        private readonly IWebHostEnvironment _environment;

        public LocalFileStorageService(IWebHostEnvironment environment)
        {
            _environment = environment;
        }

        public string? ValidateImage(IFormFile? file, long maxSizeBytes = 2 * 1024 * 1024)
        {
            if (file == null || file.Length == 0)
                return null;

            if (file.Length > maxSizeBytes)
                return "Ảnh không được lớn hơn 2MB.";

            string extension = Path.GetExtension(file.FileName);

            if (!AllowedImageExtensions.Contains(extension))
                return "Chỉ chấp nhận ảnh JPG hoặc PNG.";

            return null;
        }

        public async Task<string> SaveAsync(IFormFile file, string folder)
        {
            string normalizedFolder = folder.Trim('/', '\\');
            string uploadFolder = Path.Combine(
                _environment.WebRootPath,
                normalizedFolder.Replace('/', Path.DirectorySeparatorChar));

            Directory.CreateDirectory(uploadFolder);

            string extension = Path.GetExtension(file.FileName).ToLowerInvariant();
            string fileName = $"{Guid.NewGuid():N}{extension}";
            string fullPath = Path.Combine(uploadFolder, fileName);

            await using var stream = new FileStream(fullPath, FileMode.Create);
            await file.CopyToAsync(stream);

            return $"/{normalizedFolder.Replace('\\', '/')}/{fileName}";
        }

        public void Delete(string? relativePath)
        {
            if (string.IsNullOrWhiteSpace(relativePath))
                return;

            string normalizedPath = relativePath.TrimStart('/')
                .Replace('/', Path.DirectorySeparatorChar);

            string fullPath = Path.Combine(_environment.WebRootPath, normalizedPath);

            if (File.Exists(fullPath))
                File.Delete(fullPath);
        }
    }
}
