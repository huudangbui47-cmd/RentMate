namespace RentMate.Api.Infrastructure.Storage
{
    // Thư mục ảnh dùng chung giữa AdminSite (nơi quản trị tải lên) và Api (nơi app tải về), vd. banner trang chủ.
    // Mặc định là thư mục shared-uploads cạnh hai project; đổi bằng "Storage:SharedRoot" trong appsettings.
    // Cả hai host phải trỏ về cùng một thư mục.
    public static class SharedStorage
    {
        public const string RequestPath = "/shared";

        public static string ResolveRoot(IConfiguration configuration, IWebHostEnvironment environment)
        {
            string? configured = configuration["Storage:SharedRoot"];

            string root = string.IsNullOrWhiteSpace(configured)
                ? Path.Combine(environment.ContentRootPath, "..", "shared-uploads")
                : configured;

            root = Path.GetFullPath(root);
            Directory.CreateDirectory(root);

            return root;
        }
    }
}
