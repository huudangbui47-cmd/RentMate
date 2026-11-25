namespace RentMate.AdminSite.Infrastructure.Storage
{
    public interface IFileStorageService
    {
        string? ValidateImage(IFormFile? file, long maxSizeBytes = 2 * 1024 * 1024);
        Task<string> SaveAsync(IFormFile file, string folder);

        // Lưu vào thư mục dùng chung với Api (app tải được), trả về /shared/<folder>/<tên file>
        Task<string> SaveSharedAsync(IFormFile file, string folder);

        // Xóa được cả file trong wwwroot lẫn file dùng chung (/shared/...)
        void Delete(string? relativePath);
    }
}
