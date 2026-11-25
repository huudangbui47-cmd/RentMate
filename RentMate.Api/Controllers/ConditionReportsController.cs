using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Api.Infrastructure.Storage;
using RentMate.Service.DTOs.ConditionReports;
using RentMate.Service.Interfaces;
using RentMate.Service.Services;
using System.Security.Claims;

namespace RentMate.Api.Controllers
{
    [Route("api/rentals/{rentalId:int}/condition-reports")]
    [ApiController]
    [Authorize]
    public class ConditionReportsController : ControllerBase
    {
        private readonly IConditionReportService _conditionReportService;
        private readonly IFileStorageService _fileStorageService;

        public ConditionReportsController(
            IConditionReportService conditionReportService,
            IFileStorageService fileStorageService)
        {
            _conditionReportService = conditionReportService;
            _fileStorageService = fileStorageService;
        }

        // GET api/rentals/1/condition-reports
        [HttpGet]
        public async Task<IActionResult> GetAll(int rentalId)
        {
            try
            {
                return Ok(await _conditionReportService.GetByRentalAsync(rentalId, GetUserId()));
            }
            catch (ArgumentException ex)
            {
                return NotFound(ex.Message);
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
        }

        // POST api/rentals/1/condition-reports  (multipart: reportType, condition, description, files)
        // AI xem ảnh nên request có thể mất 10-30 giây
        [HttpPost]
        [RequestSizeLimit(15 * 1024 * 1024)]
        public async Task<IActionResult> Create(
            int rentalId,
            [FromForm] CreateConditionReportDto dto,
            [FromForm] List<IFormFile> files)
        {
            if (files == null || files.Count == 0)
                return BadRequest("Cần chụp ít nhất 1 ảnh món đồ.");

            // Số ảnh tối đa theo cài đặt do service kiểm tra; ở đây chỉ chặn số lượng vượt mức cài đặt cho phép (12) trước khi lưu file
            if (files.Count > 12)
                return BadRequest("Mỗi biên bản tối đa 12 ảnh.");

            foreach (var file in files)
            {
                string? imageError = _fileStorageService.ValidateImage(file);

                if (imageError != null)
                    return BadRequest($"{file.FileName}: {imageError}");
            }

            var savedUrls = new List<string>();

            try
            {
                var images = new List<ReportImageFile>();

                foreach (var file in files)
                {
                    await using var memory = new MemoryStream();
                    await file.CopyToAsync(memory);
                    images.Add(new ReportImageFile(memory.ToArray(), MediaTypeOf(file.FileName)));

                    savedUrls.Add(await _fileStorageService.SaveAsync(file, "uploads/reports"));
                }

                // Đọc ảnh biên bản trước và ảnh tin đăng để AI so sánh (đúng món, hư hỏng mới)
                var (referenceUrls, listingUrls) =
                    await _conditionReportService.GetReferenceImageUrlsAsync(rentalId, dto.ReportType);

                var report = await _conditionReportService.CreateAsync(
                    rentalId, dto, GetUserId(), savedUrls, images,
                    await ReadImagesAsync(referenceUrls), await ReadImagesAsync(listingUrls));

                return Ok(report);
            }
            catch (UnauthorizedAccessException)
            {
                DeleteFiles(savedUrls);
                return Forbid();
            }
            catch (Exception ex) when (ex is ArgumentException or InvalidOperationException)
            {
                DeleteFiles(savedUrls);
                return BadRequest(ex.Message);
            }
        }

        private async Task<List<ReportImageFile>> ReadImagesAsync(List<string> urls)
        {
            var result = new List<ReportImageFile>();

            foreach (var url in urls)
            {
                var content = await _fileStorageService.ReadAsync(url);

                if (content != null)
                    result.Add(new ReportImageFile(content, MediaTypeOf(url)));
            }

            return result;
        }

        private static string MediaTypeOf(string fileName) =>
            fileName.EndsWith(".png", StringComparison.OrdinalIgnoreCase) ? "image/png" : "image/jpeg";

        private void DeleteFiles(IEnumerable<string> urls)
        {
            foreach (var url in urls)
                _fileStorageService.Delete(url);
        }

        private string GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        }
    }
}
