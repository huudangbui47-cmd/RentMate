using Microsoft.AspNetCore.Identity;
using RentMate.Core.Models;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Infrastructure
{
    public static class DbSeeder
    {
        public static async Task SeedRolesAsync(IServiceProvider services)
        {
            using var scope = services.CreateScope();

            var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();

            string[] roleNames = { "Admin", "Manager", "User" };

            foreach (var roleName in roleNames)
            {
                bool exists = await roleManager.RoleExistsAsync(roleName);

                if (!exists)
                {
                    await roleManager.CreateAsync(new IdentityRole(roleName));
                }
            }
        }

        // Câu chữ của app (và bản tiếng Anh có sẵn) cho trang Ngôn ngữ: chỉ thêm câu còn thiếu,
        // không ghi đè bản dịch admin đã sửa. Cập nhật code app có câu mới thì lần chạy sau tự bổ sung.
        public static async Task SeedTextsAsync(IServiceProvider services)
        {
            using var scope = services.CreateScope();

            var localizationService = scope.ServiceProvider.GetRequiredService<ILocalizationService>();

            await localizationService.ImportDefaultsAsync(null, "Hệ thống");
        }

        public static async Task SeedAdminAsync(IServiceProvider services, IConfiguration configuration)
        {
            using var scope = services.CreateScope();

            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();

            // 1. Nếu hệ thống đã có Admin thì không tạo thêm
            var admins = await userManager.GetUsersInRoleAsync("Admin");

            if (admins.Count > 0)
            {
                return;
            }

            // 2. Lấy thông tin Admin đầu tiên
            string email = configuration["SeedAdmin:Email"]?.Trim() ?? throw new InvalidOperationException("Chưa cấu hình SeedAdmin:Email.");

            string password = configuration["SeedAdmin:Password"] ?? throw new InvalidOperationException("Chưa cấu hình SeedAdmin:Password.");

            string fullName = configuration["SeedAdmin:FullName"]?.Trim() ?? throw new InvalidOperationException("Chưa cấu hình SeedAdmin:FullName.");

            // 3. Không cho tạo Admin nếu email đã thuộc tài khoản khác
            var existingUser = await userManager.FindByEmailAsync(email);

            if (existingUser != null)
            {
                throw new InvalidOperationException("Email dùng để seed Admin đã tồn tại.");
            }

            // 4. Tạo tài khoản Admin
            var admin = new ApplicationUser
            {
                FullName = fullName,
                Email = email,
                UserName = email,
                EmailConfirmed = true,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            var result = await userManager.CreateAsync(admin, password);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException("Không tạo được Admin: " + string.Join(" ", result.Errors.Select(e => e.Description)));
            }

            await userManager.AddToRoleAsync(admin, "Admin");
        }
    }
}
