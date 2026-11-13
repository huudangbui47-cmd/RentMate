namespace RentMate.Service.DTOs.Items
{
    public class ItemImageDto
    {
        public int ImageId { get; set; }

        // Đường dẫn tương đối trên Api, ví dụ /uploads/items/abc.jpg
        public string ImageUrl { get; set; } = string.Empty;

        public bool IsPrimary { get; set; }
    }
}
