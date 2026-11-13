namespace RentMate.Api.Infrastructure.Storage
{
    public interface IFileStorageService
    {
        string? ValidateImage(IFormFile? file, long maxSizeBytes = 2 * 1024 * 1024);
        Task<string> SaveAsync(IFormFile file, string folder);
        void Delete(string? relativePath);
    }
}
