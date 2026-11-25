namespace RentMate.Core.Models
{
    public class Category : BaseEntity
    {
        public string CategoryName { get; set; } = string.Empty;

        public string? Description { get; set; }

        public bool IsActive { get; set; } = true;

        // Tên icon hiển thị trên app (smartphone, laptop, camera...), danh sách trong CategoryIcons
        public string? Icon { get; set; }

        // Danh mục chỉ có 2 cấp: null là danh mục cha, có giá trị là danh mục con
        public int? ParentCategoryId { get; set; }

        public Category? ParentCategory { get; set; }

        public ICollection<Category> Children { get; set; } = new List<Category>();

        // SQL Server tự đổi giá trị mỗi lần bản ghi thay đổi
        public byte[] RowVersion { get; set; } = Array.Empty<byte>();

        public ICollection<Item> Items { get; set; } = new List<Item>();
    }
}
