namespace RentMate.Core.Models
{
    public class Category : BaseEntity
    {
        public string CategoryName { get; set; } = string.Empty;

        public string? Description { get; set; }

        public bool IsActive { get; set; } = true;

        // SQL Server tự đổi giá trị mỗi lần bản ghi thay đổi
        public byte[] RowVersion { get; set; } = Array.Empty<byte>();

        public ICollection<Item> Items { get; set; } = new List<Item>();
    }
}