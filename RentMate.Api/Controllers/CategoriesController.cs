using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.DTOs.Categories;
using RentMate.Service.Interfaces;

namespace RentMate.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CategoriesController : ControllerBase
    {
        private readonly ICategoryService _categoryService;

        public CategoriesController(
            ICategoryService categoryService)
        {
            _categoryService = categoryService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            return Ok(
                await _categoryService.GetAllAsync());
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var category =
                await _categoryService.GetByIdAsync(id);

            if (category == null)
                return NotFound();

            return Ok(category);
        }

        [Authorize]
        [HttpPost]
        public async Task<IActionResult> Create(
            CreateCategoryDto dto)
        {
            try
            {
                var result =
                    await _categoryService.CreateAsync(dto);

                return CreatedAtAction(
                    nameof(GetById),
                    new { id = result.CategoryId },
                    result);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}