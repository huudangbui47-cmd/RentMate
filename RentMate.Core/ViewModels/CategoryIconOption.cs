namespace RentMate.Core.ViewModels
{
    // Icon chọn được cho danh mục. Key trùng tên icon app Flutter dùng (lib/widgets/ui.dart → categoryIconByKey).
    public class CategoryIconOption
    {
        public string Key { get; set; } = string.Empty;

        // Có emoji để admin nhìn là biết (trang quản trị không nạp bộ icon của app)
        public string Label { get; set; } = string.Empty;

        public static readonly List<CategoryIconOption> All = new()
        {
            new() { Key = "smartphone", Label = "📱 Điện thoại" },
            new() { Key = "laptop", Label = "💻 Máy tính" },
            new() { Key = "headphones", Label = "🎧 Âm thanh" },
            new() { Key = "camera", Label = "📷 Máy ảnh, máy quay" },
            new() { Key = "devices", Label = "🔌 Đồ điện tử khác" },
            new() { Key = "game", Label = "🎮 Trò chơi" },
            new() { Key = "bike", Label = "🚲 Xe đạp" },
            new() { Key = "motorbike", Label = "🛵 Xe máy" },
            new() { Key = "car", Label = "🚗 Ô tô" },
            new() { Key = "camping", Label = "⛺ Du lịch, cắm trại" },
            new() { Key = "sports", Label = "⚽ Thể thao" },
            new() { Key = "fashion", Label = "👗 Thời trang" },
            new() { Key = "book", Label = "📚 Sách" },
            new() { Key = "kitchen", Label = "🍳 Nhà bếp, gia dụng" },
            new() { Key = "tools", Label = "🛠 Dụng cụ" },
            new() { Key = "music", Label = "🎸 Nhạc cụ" },
            new() { Key = "baby", Label = "🍼 Mẹ và bé" },
            new() { Key = "party", Label = "🎉 Sự kiện, tiệc" },
            new() { Key = "furniture", Label = "🛋 Nội thất" },
            new() { Key = "other", Label = "📦 Khác" },
        };

        public static string? LabelOf(string? key) => All.FirstOrDefault(o => o.Key == key)?.Label;
    }
}
