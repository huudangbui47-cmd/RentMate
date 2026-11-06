using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
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

        public ItemsController(IItemService itemService)
        {
            _itemService = itemService;
        }

        // GET: api/items
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var items =
                await _itemService.GetAllAsync();

            return Ok(items);
        }

        // GET: api/items/5
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var item =
                await _itemService.GetByIdAsync(id);

            if (item == null)
            {
                return NotFound();
            }

            return Ok(item);
        }

        // POST: api/items
        [Authorize]
        [HttpPost]
        public async Task<IActionResult> Create(
            CreateItemDto dto)
        {
            var ownerId =
                User.FindFirstValue(
                    ClaimTypes.NameIdentifier);

            if (string.IsNullOrEmpty(ownerId))
            {
                return Unauthorized();
            }

            try
            {
                var item =
                    await _itemService.CreateAsync(
                        dto,
                        ownerId);

                return CreatedAtAction(
                    nameof(GetById),
                    new { id = item.ItemId },
                    item);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // PUT: api/items/5
        [Authorize]
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(
            int id,
            UpdateItemDto dto)
        {
            var ownerId =
                User.FindFirstValue(
                    ClaimTypes.NameIdentifier);

            if (string.IsNullOrEmpty(ownerId))
            {
                return Unauthorized();
            }

            try
            {
                var result =
                    await _itemService.UpdateAsync(
                        id,
                        dto,
                        ownerId);

                if (!result)
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
            var ownerId =
                User.FindFirstValue(
                    ClaimTypes.NameIdentifier);

            if (string.IsNullOrEmpty(ownerId))
            {
                return Unauthorized();
            }

            try
            {
                var result =
                    await _itemService.DeleteAsync(
                        id,
                        ownerId);

                if (!result)
                {
                    return NotFound();
                }

                return NoContent();
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
        }
    }
}