using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using RentMate.Api.Security;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Data.Context;
using RentMate.Data.UnitOfWork;
using RentMate.Service.DTOs;
using RentMate.Service.Interfaces;
using RentMate.Service.Services;
using System.Security.Claims;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// =========================
// 1. Controllers
// =========================
builder.Services.AddControllers();

// =========================
// 2. Database
// =========================
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection")));

// =========================
// 3. Identity (chỉ dùng UserManager/RoleManager, API xác thực bằng JWT)
// =========================
builder.Services.AddIdentityCore<ApplicationUser>(options =>
    {
        options.User.RequireUniqueEmail = true;
        options.Lockout.MaxFailedAccessAttempts = 5;
        options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
    })
    .AddRoles<IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>();

// =========================
// 4. Repository / UnitOfWork + Services
// =========================
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();

builder.Services.AddScoped<IAuditLogService, AuditLogService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ICategoryService, CategoryService>();
builder.Services.AddScoped<IItemService, ItemService>();
builder.Services.AddScoped<IRentalService, RentalService>();
builder.Services.AddScoped<IConditionReportService, ConditionReportService>();
builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();

// =========================
// 5. JWT Authentication
// =========================
var jwtKey = builder.Configuration["Jwt:Key"]
    ?? throw new InvalidOperationException("JWT Key is missing.");

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme =
        JwtBearerDefaults.AuthenticationScheme;

    options.DefaultChallengeScheme =
        JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,

        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidAudience = builder.Configuration["Jwt:Audience"],

        IssuerSigningKey = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(jwtKey)),

        ClockSkew = TimeSpan.Zero
    };

    // Token còn hạn nhưng tài khoản đã bị khóa hoặc mật khẩu đã bị đổi/đặt lại thì không dùng được nữa
    options.Events = new JwtBearerEvents
    {
        OnTokenValidated = async context =>
        {
            string? userId = context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier);
            string? securityStamp = context.Principal?.FindFirstValue(SessionClaimTypes.SecurityStamp);

            var authService = context.HttpContext.RequestServices.GetRequiredService<IAuthService>();

            if (userId == null || !await authService.IsSessionValidAsync(userId, securityStamp))
                context.Fail("Phiên đăng nhập không còn hiệu lực. Vui lòng đăng nhập lại.");
        }
    };
});

builder.Services.AddAuthorization();

// =========================
// 6. CORS
// =========================
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutter", policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

// =========================
// 7. Swagger
// =========================
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "RentMate API",
        Version = "v1"
    });

    options.AddSecurityDefinition(
        "Bearer",
        new OpenApiSecurityScheme
        {
            Name = "Authorization",
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT",
            In = ParameterLocation.Header,
            Description = "Dán JWT nhận từ POST /api/auth/login."
        });

    // Chỉ hiện biểu tượng khóa ở API có [Authorize]
    options.OperationFilter<AuthorizeOperationFilter>();
});

var app = builder.Build();

// =========================
// HTTP Pipeline
// =========================
// Lỗi không lường trước trả Problem Details JSON
app.UseExceptionHandler(handler => handler.Run(async context =>
{
    await Results.Problem(
        statusCode: StatusCodes.Status500InternalServerError,
        title: "Lỗi máy chủ",
        detail: "Không thể xử lý yêu cầu API. Vui lòng thử lại sau.")
        .ExecuteAsync(context);
}));

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseCors("AllowFlutter");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
