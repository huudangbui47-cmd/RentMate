namespace RentMate.Service.DTOs.Items
{
    // 34 tỉnh/thành sau sắp xếp đơn vị hành chính từ 01/07/2025
    public static class VietnamProvinces
    {
        public static readonly IReadOnlyList<string> All = new[]
        {
            // 6 thành phố trực thuộc trung ương
            "Hà Nội", "TP. Hồ Chí Minh", "Hải Phòng", "Đà Nẵng", "Cần Thơ", "Huế",

            // 28 tỉnh
            "An Giang", "Bắc Ninh", "Cà Mau", "Cao Bằng", "Đắk Lắk", "Điện Biên", "Đồng Nai",
            "Đồng Tháp", "Gia Lai", "Hà Tĩnh", "Hưng Yên", "Khánh Hòa", "Lai Châu", "Lâm Đồng",
            "Lạng Sơn", "Lào Cai", "Nghệ An", "Ninh Bình", "Phú Thọ", "Quảng Ngãi", "Quảng Ninh",
            "Quảng Trị", "Sơn La", "Tây Ninh", "Thái Nguyên", "Thanh Hóa", "Tuyên Quang", "Vĩnh Long"
        };

        public static bool IsValid(string? province)
            => province != null && All.Contains(province);
    }
}
