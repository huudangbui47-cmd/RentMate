namespace RentMate.Core.Models
{
    public class Category : BaseEntity
    {
        public string CategoryName { get; set; } = string.Empty;

        public string? Description { get; set; }

        public bool IsActive { get; set; } = true;

        public ICollection<Item> Items { get; set; } = new List<Item>();
    }
}