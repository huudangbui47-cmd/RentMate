namespace RentMate.Core.Models
{
    /// <summary>
    /// Lớp cơ sở cho mọi entity có khóa chính kiểu int.
    /// Tên cột trong DB vẫn giữ nguyên (CategoryId, ItemId, ...) nhờ cấu hình
    /// HasColumnName trong tầng Data, nên không cần đổi schema.
    /// </summary>
    public abstract class BaseEntity
    {
        public int Id { get; set; }
    }
}
