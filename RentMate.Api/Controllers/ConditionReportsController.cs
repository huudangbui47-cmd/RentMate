using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Api.Infrastructure.Storage;
using RentMate.Core.Enums;
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

            if (files.Count > ConditionReportService.MaxImages)
                return BadRequest($"Mỗi biên bản tối đa {ConditionReportService.MaxImages} ảnh.");

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

                // Biên bản lúc nhận lại: đọc ảnh lúc giao để AI so sánh
                var beforeImages = new List<ReportImageFile>();

                if (dto.ReportType == ConditionReportType.AfterRental)
                {
                    foreach (var url in await _conditionReportService.GetBeforeImageUrlsAsync(rentalId))
                    {
                        var content = await _fileStorageService.ReadAsync(url);

                        if (content != null)
                            beforeImages.Add(new ReportImageFile(content, MediaTypeOf(url)));
                    }
                }

                var report = await _conditionReportService.CreateAsync(
                    rentalId, dto, GetUserId(), savedUrls, images, beforeImages);

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
