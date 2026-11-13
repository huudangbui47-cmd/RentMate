using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Api.Infrastructure.Storage;
using RentMate.Service.DTOs.Items;
using RentMate.Service.Interfaces;
using System.Security.Claims;

namespace RentMate.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ItemsController : ControllerBase
    {
        private readonly IItemService _itemService;
        private readonly IFileStorageService _fileStorageService;

        public ItemsController(IItemService itemService, IFileStorageService fileStorageService)
        {
            _itemService = itemService;
            _fileStorageService = fileStorageService;
        }

        // GET: api/items  (chỉ đồ đã được duyệt)
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            return Ok(await _itemService.GetAllAsync());
        }

        // GET: api/items/my  (đồ của tôi, mọi trạng thái kể cả chờ duyệt / bị từ chối)
        [Authorize]
        [HttpGet("my")]
        public async Task<IActionResult> GetMine()
        {
            return Ok(await _itemService.GetMyItemsAsync(GetUserId()!));
        }

        // GET: api/items/5
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            // Không bắt buộc đăng nhập; có token thì chủ đồ xem được đồ chưa duyệt của mình
            var item = await _itemService.GetByIdAsync(id, GetUserId());

            if (item == null)
            {
                return NotFound();
            }

            return Ok(item);
        }

        // POST: api/items
        [Authorize]
        [HttpPost]
        public async Task<IActionResult> Create(CreateItemDto dto)
        {
            try
            {
                var item = await _itemService.CreateAsync(dto, GetUserId()!);

                return CreatedAtAction(nameof(GetById), new { id = item.ItemId }, item);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // PUT: api/items/5
        [Authorize]
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, UpdateItemDto dto)
        {
            try
            {
                if (!await _itemService.UpdateAsync(id, dto, GetUserId()!))
                {
                    return NotFound();
                }

                return NoContent();
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // DELETE: api/items/5
        [Authorize]
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                if (!await _itemService.DeleteAsync(id, GetUserId()!))
                {
                    return NotFound();
                }

                return NoContent();
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // POST: api/items/5/images  (multipart, field "files", chọn nhiều ảnh một lần)
        [Authorize]
        [HttpPost("{id}/images")]
        [RequestSizeLimit(20 * 1024 * 1024)]
        public async Task<IActionResult> UploadImages(int id, [FromForm] List<IFormFile> files)
        {
            files = files.Where(f => f.Length > 0).ToList();

            if (files.Count == 0)
            {
                return BadRequest("Vui lòng chọn ít nhất 1 ảnh.");
            }

            foreach (var file in files)
            {
                string? imageError = _fileStorageService.ValidateImage(file);

                if (imageError != null)
                {
                    return BadRequest($"{file.FileName}: {imageError}");
                }
            }

            var savedUrls = new List<string>();

            try
            {
                foreach (var file in files)
                {
                    savedUrls.Add(await _fileStorageService.SaveAsync(file, "uploads/items"));
                }

                var images = await _itemService.AddImagesAsync(id, savedUrls, GetUserId()!);

                if (images == null)
                {
                    DeleteFiles(savedUrls);
                    return NotFound();
                }

                return Ok(images);
            }
            catch (UnauthorizedAccessException)
            {
                DeleteFiles(savedUrls);
                return Forbid();
            }
            catch (ArgumentException ex)
            {
                DeleteFiles(savedUrls);
                return BadRequest(ex.Message);
            }
            catch
            {
                DeleteFiles(savedUrls);
                throw;
            }
        }

        // DELETE: api/items/5/images/12
        [Authorize]
        [HttpDelete("{id}/images/{imageId}")]
        public async Task<IActionResult> DeleteImage(int id, int imageId)
        {
            try
            {
                string? imageUrl = await _itemService.DeleteImageAsync(id, imageId, GetUserId()!);

                if (imageUrl == null)
                {
                    return NotFound();
                }

                _fileStorageService.Delete(imageUrl);

                return NoContent();
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // PUT: api/items/5/images/12/primary  (đặt làm ảnh chính)
        [Authorize]
        [HttpPut("{id}/images/{imageId}/primary")]
        public async Task<IActionResult> SetPrimaryImage(int id, int imageId)
        {
            try
            {
                if (!await _itemService.SetPrimaryImageAsync(id, imageId, GetUserId()!))
                {
                    return NotFound();
                }

                return NoContent();
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        private void DeleteFiles(IEnumerable<string> urls)
        {
            foreach (string url in urls)
            {
                _fileStorageService.Delete(url);
            }
        }

        private string? GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier);
        }
    }
}
