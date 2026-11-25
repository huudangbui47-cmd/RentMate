namespace RentMate.AdminSite.Infrastructure.Storage
{
    public class LocalFileStorageService : IFileStorageService
    {
        private static readonly HashSet<string> AllowedImageExtensions =
            new(StringComparer.OrdinalIgnoreCase) { ".jpg", ".jpeg", ".png" };

        private readonly IWebHostEnvironment _environment;
        private readonly string _sharedRoot;

        public LocalFileStorageService(IWebHostEnvironment environment, IConfiguration configuration)
        {
            _environment = environment;
            _sharedRoot = SharedStorage.ResolveRoot(configuration, environment);
        }

        public string? ValidateImage(IFormFile? file, long maxSizeBytes = 2 * 1024 * 1024)
        {
            if (file == null || file.Length == 0)
                return null;

            if (file.Length > maxSizeBytes)
                return $"Ảnh không được lớn hơn {maxSizeBytes / (1024 * 1024)}MB.";

            string extension = Path.GetExtension(file.FileName);

            if (!AllowedImageExtensions.Contains(extension))
                return "Chỉ chấp nhận ảnh JPG hoặc PNG.";

            return null;
        }

        public Task<string> SaveAsync(IFormFile file, string folder)
        {
            return SaveToAsync(file, folder, _environment.WebRootPath, string.Empty);
        }

        public Task<string> SaveSharedAsync(IFormFile file, string folder)
        {
            return SaveToAsync(file, folder, _sharedRoot, SharedStorage.RequestPath);
        }

        private static async Task<string> SaveToAsync(IFormFile file, string folder, string root, string urlPrefix)
        {
            string normalizedFolder = folder.Trim('/', '\\');
            string uploadFolder = Path.Combine(
                root,
                normalizedFolder.Replace('/', Path.DirectorySeparatorChar));

            Directory.CreateDirectory(uploadFolder);

            string extension = Path.GetExtension(file.FileName).ToLowerInvariant();
            string fileName = $"{Guid.NewGuid():N}{extension}";
            string fullPath = Path.Combine(uploadFolder, fileName);

            await using var stream = new FileStream(fullPath, FileMode.Create);
            await file.CopyToAsync(stream);

            return $"{urlPrefix}/{normalizedFolder.Replace('\\', '/')}/{fileName}";
        }

        public void Delete(string? relativePath)
        {
            if (string.IsNullOrWhiteSpace(relativePath))
                return;

            string root = _environment.WebRootPath;

            // Ảnh dùng chung (/shared/...) nằm ở thư mục riêng, không phải wwwroot
            if (relativePath.StartsWith(SharedStorage.RequestPath + "/", StringComparison.OrdinalIgnoreCase))
            {
                root = _sharedRoot;
                relativePath = relativePath.Substring(SharedStorage.RequestPath.Length);
            }

            root = Path.GetFullPath(root);
            string fullPath = Path.GetFullPath(Path.Combine(root,
                relativePath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar)));

            // Chặn "../" đi ra ngoài thư mục ảnh
            if (!fullPath.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                return;

            if (File.Exists(fullPath))
                File.Delete(fullPath);
        }
    }
}
