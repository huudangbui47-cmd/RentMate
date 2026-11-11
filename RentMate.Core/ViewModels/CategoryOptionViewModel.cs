namespace RentMate.Core.ViewModels
{
    public class CategoryOptionViewModel
    {
        public int Id { get; set; }
        public string CategoryName { get; set; } = string.Empty;

        // Có giá trị nghĩa là danh mục con, hiển thị thụt vào dưới danh mục cha
        public int? ParentCategoryId { get; set; }
    }
}
