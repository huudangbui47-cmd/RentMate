using System.ComponentModel.DataAnnotations;

namespace RentMate.Api.DTOs.Categories
{
    public class CreateCategoryDto
    {
        [Required]
        public string CategoryName { get; set; } = string.Empty;

        public string? Description { get; set; }
    }
}