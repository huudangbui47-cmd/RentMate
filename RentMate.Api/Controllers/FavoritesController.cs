using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.Interfaces;
using System.Security.Claims;

namespace RentMate.Api.Controllers
{
    // Danh sách yêu thích (tim trên app)
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class FavoritesController : ControllerBase
    {
        private readonly IFavoriteService _favoriteService;

        public FavoritesController(IFavoriteService favoriteService)
        {
            _favoriteService = favoriteService;
        }

        // GET: api/favorites  (đồ đã lưu, mới lưu đứng đầu)
        [HttpGet]
        public async Task<IActionResult> GetMine()
        {
            return Ok(await _favoriteService.GetMineAsync(GetUserId()));
        }

        // GET: api/favorites/ids  (để tô tim đen ở Trang chủ, chi tiết đồ)
        [HttpGet("ids")]
        public async Task<IActionResult> GetMyIds()
        {
            return Ok(await _favoriteService.GetMyIdsAsync(GetUserId()));
        }

        // POST: api/favorites/5
        [HttpPost("{itemId}")]
        public async Task<IActionResult> Add(int itemId)
        {
            if (!await _favoriteService.AddAsync(GetUserId(), itemId))
                return NotFound();

            return NoContent();
        }

        // DELETE: api/favorites/5
        [HttpDelete("{itemId}")]
        public async Task<IActionResult> Remove(int itemId)
        {
            await _favoriteService.RemoveAsync(GetUserId(), itemId);

            return NoContent();
        }

        private string GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        }
    }
}
