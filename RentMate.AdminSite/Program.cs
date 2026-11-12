using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RentMate.AdminSite.Infrastructure;
using RentMate.AdminSite.Infrastructure.Storage;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Data.Context;
using RentMate.Data.UnitOfWork;
using RentMate.Service.DTOs;
using RentMate.Service.Interfaces;
using RentMate.Service.Services;
using System.Globalization;

var builder = WebApplication.CreateBuilder(args);

var viCulture = new CultureInfo("vi-VN");

CultureInfo.DefaultThreadCurrentCulture = viCulture;
CultureInfo.DefaultThreadCurrentUICulture = viCulture;

// Add services to the container.
builder.Services.AddControllersWithViews();

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

builder.Services.AddDbContext<ApplicationDbContext>(options => options.UseSqlServer(connectionString));

// Identity: chỉ dùng UserManager/RoleManager để quản lý tài khoản, đăng nhập bằng Cookie bên dưới
builder.Services.AddIdentityCore<ApplicationUser>(options =>
    {
        options.User.RequireUniqueEmail = true;
        options.Lockout.MaxFailedAccessAttempts = 5;
        options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
    })
    .AddRoles<IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders(); // sinh token cho link "Quên mật khẩu"

// Link đặt lại mật khẩu gửi qua email hết hạn sau 30 phút
builder.Services.Configure<DataProtectionTokenProviderOptions>(options => options.TokenLifespan = TimeSpan.FromMinutes(30));

// Cấu hình gửi email (mục "Smtp" trong appsettings)
builder.Services.Configure<SmtpSettings>(builder.Configuration.GetSection("Smtp"));

builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();

builder.Services.AddScoped<IAuditLogService, AuditLogService>();
builder.Services.AddScoped<IEmailService, SmtpEmailService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IAccountService, AccountService>();
builder.Services.AddScoped<ICustomerService, CustomerService>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddScoped<ICategoryService, CategoryService>();
builder.Services.AddScoped<IItemService, ItemService>();
builder.Services.AddScoped<IRentalService, RentalService>();
builder.Services.AddScoped<IWalletService, WalletService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddScoped<IFileStorageService, LocalFileStorageService>();

// Website quản trị chỉ dùng Cookie Authentication; JWT được cấu hình ở project API riêng.
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(CookieAuthenticationDefaults.AuthenticationScheme, options =>
    {
        options.LoginPath = "/Account/Login";
        options.AccessDeniedPath = "/Error/403";
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;

        // Đăng xuất phiên đang mở khi tài khoản bị khóa hoặc đổi/đặt lại mật khẩu
        options.Events.OnValidatePrincipal = CookieSessionValidator.ValidateAsync;
    });

var app = builder.Build();

await DbSeeder.SeedRolesAsync(app.Services);

await DbSeeder.SeedAdminAsync(app.Services, app.Configuration);

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error/500");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

// Chỉ MVC: lỗi hiển thị trang Razor /Error/{code}.
app.UseStatusCodePagesWithReExecute("/Error/{0}");

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "areas",
    pattern: "{area:exists}/{controller=Dashboard}/{action=Index}/{id?}");

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Account}/{action=Login}/{id?}");

app.Run();
