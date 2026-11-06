# RentMate

Hệ thống cho thuê đồ gồm **API cho app Flutter** và **trang quản trị web**.
Công nghệ: ASP.NET Core 8, SQL Server, EF Core 8, ASP.NET Identity, JWT (API) / Cookie (Admin), theme quản trị Mazer.

## Kiến trúc

Cấu trúc giống project EcommerceManagement: 5 project nằm cùng cấp trong solution.

```
RentMate.sln
├── RentMate.AdminSite   Web quản trị MVC (Cookie, Area "Management", chỉ role Admin)
├── RentMate.Api         REST API cho app di động (JWT, Swagger)
├── RentMate.Core        Models, Enums, Interfaces/Persistence (IRepository, IUnitOfWork), ViewModels
├── RentMate.Data        Context, Configurations, Migrations, Repository, UnitOfWork
└── RentMate.Service     DTOs, Interfaces, Services
```

Tham chiếu giữa các project:

| Project | Tham chiếu tới |
|---|---|
| Core | (không) |
| Data | Core |
| Service | Core |
| Api | Data, Service |
| AdminSite | Data, Service |

- Controller chỉ gọi tới **Interface** của Service (vd. `ICategoryService`), không gọi thẳng class cài đặt.
- Service làm việc với DB qua `IUnitOfWork` / `IRepository<T>`, không dùng `DbContext` trực tiếp.
- Việc đăng ký DI (`AddScoped<IXxxService, XxxService>()`) nằm trong **`Program.cs`** của từng host.
- `ApplicationUser` dùng ASP.NET Identity (khóa kiểu string) nên được thao tác qua `UserManager`, không nằm trong `IUnitOfWork`.

### Quy ước khi thêm chức năng

| Việc cần làm | Đặt ở đâu |
|---|---|
| Thêm bảng mới | `Core/Models` (kế thừa `BaseEntity`) → `Data/Configurations/<Nhóm>/XxxConfiguration.cs` → thêm `DbSet` vào `ApplicationDbContext` + repository vào `IUnitOfWork`/`UnitOfWork` → tạo migration |
| Logic nghiệp vụ | `Service/Interfaces/IXxxService.cs` + `Service/Services/XxxService.cs`, rồi đăng ký trong `Program.cs` của Api và/hoặc AdminSite |
| Dữ liệu trả cho app | `Service/DTOs/<Nhóm>/` |
| Dữ liệu cho trang quản trị | `Core/ViewModels/` (mỗi class 1 file, text hiển thị như `StatusText` đặt trong ViewModel) |
| Báo lỗi nghiệp vụ ở trang quản trị | Service ném `InvalidOperationException("...")`, controller `catch` rồi đưa vào `ModelState` hoặc `TempData["Error"]` |
| Trang quản trị mới | Controller có `[Area("Management")]`, `[Authorize(Roles = "Admin")]`, kế thừa `ManagementControllerBase`; view trong `Areas/Management/Views/<Tên>/` |
| Ghi nhật ký thao tác admin | Gọi `IAuditLogService.RecordAsync(...)` trước `SaveChangesAsync()`, thêm tên hiển thị vào `ActionText` của `AuditLogItemViewModel` |

> Các entity dùng thuộc tính `Id` (từ `BaseEntity`), nhưng cột trong DB vẫn giữ tên cũ (`CategoryId`, `ItemId`, ...) nhờ `HasColumnName` trong Configurations. DTO trả cho app vẫn giữ tên `CategoryId`, `ItemId`, ... như trước.

## Cài đặt sau khi clone

### 1. Tạo file cấu hình
File `appsettings.json` và `appsettings.Development.json` **không được đưa lên GitHub**. Tạo 2 file sau:

**`RentMate.Api/appsettings.Development.json`**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\MSSQLLocalDB;Database=RentMateDb;Trusted_Connection=True;TrustServerCertificate=True"
  },
  "Jwt": {
    "Key": "chuoi-bi-mat-dai-it-nhat-32-ky-tu",
    "Issuer": "RentMate",
    "Audience": "RentMateClient"
  }
}
```

**`RentMate.AdminSite/appsettings.Development.json`**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\MSSQLLocalDB;Database=RentMateDb;Trusted_Connection=True;TrustServerCertificate=True"
  },
  "SeedAdmin": {
    "Email": "admin@rentmate.local",
    "Password": "Admin@123",
    "FullName": "Quản trị viên"
  }
}
```

- `Jwt:Key` phải dài ít nhất 32 ký tự.
- `SeedAdmin`: khi **AdminSite** khởi động, `Infrastructure/DbSeeder.cs` tạo 2 role `Admin`, `User` và tài khoản Admin này nếu hệ thống chưa có Admin nào. Nên chạy AdminSite ít nhất 1 lần trước, để user đăng ký từ app được gán role `User`. Mật khẩu phải có chữ hoa, chữ thường, số và ký tự đặc biệt. **Nên đổi mật khẩu** sau lần đăng nhập đầu.
- Nếu không dùng LocalDB, sửa phần `Server=` cho phù hợp với SQL Server trên máy.

### 2. Tạo / cập nhật database
Visual Studio → Tools → NuGet Package Manager → Package Manager Console:
- **Startup project**: `RentMate.Api`
- **Default project** (dropdown trong console): `RentMate.Data`

```
Update-Database
```

Hoặc dùng CLI:
```
dotnet ef database update --project RentMate.Data --startup-project RentMate.Api
```

Thêm migration mới:
```
dotnet ef migrations add TenMigration --project RentMate.Data --startup-project RentMate.Api
```

### 3. Chạy
Chạy cùng lúc Api và AdminSite: chuột phải Solution → **Configure Startup Projects** → **Multiple startup projects** → chọn `Start` (Debug target `https`) cho `RentMate.AdminSite` và `RentMate.Api` → bấm **Save Profile** → chọn profile đó trên thanh công cụ → F5.
(VS lưu profile vào `RentMate.slnLaunch.user`, file này không được commit nên mỗi máy tự tạo một lần.)

| Host | URL | Ghi chú |
|---|---|---|
| RentMate.Api | https://localhost:7130/swagger | Login lấy token rồi bấm **Authorize** |
| RentMate.AdminSite | https://localhost:7140 | Đăng nhập bằng tài khoản `SeedAdmin` |

## Trang quản trị

| Mục | Chức năng |
|---|---|
| Tổng quan | Số liệu người dùng / đồ / đơn, doanh thu 6 tháng, đơn mới nhất, đồ được thuê nhiều |
| Đơn thuê | Lọc theo trạng thái, tìm theo mã/tên; xem chi tiết tiến trình, thanh toán, biên bản tình trạng |
| Đồ cho thuê | Lọc theo danh mục/trạng thái; tạm ngưng, ẩn hoặc mở lại đồ |
| Danh mục | Thêm, sửa, bật/tắt |
| Thanh toán | Lọc theo trạng thái/loại/ngày, tổng tiền đã thu |
| Người dùng | Khóa/mở khóa, cấp/gỡ quyền quản trị |
| Nhật ký hệ thống | Lịch sử đăng nhập và thao tác quản trị |

Giao diện dựa trên layout, CSS và JS của project EcommerceManagement (theme [Mazer](https://github.com/zuramai/mazer), MIT). Thư viện được đặt sẵn trong `RentMate.AdminSite/wwwroot/lib`, không phụ thuộc CDN. Chỉnh giao diện riêng cho RentMate thì sửa ở `wwwroot/css/rentmate.css`.

## Quy trình làm việc nhóm
- Không push thẳng lên `main`.
- Mỗi việc làm trên một nhánh riêng: `feature/...`, `fix/...`, `docs/...`
- Commit theo dạng: `feat: ...`, `fix: ...`, `refactor: ...`, `docs: ...`, `chore: ...`
- Làm xong thì mở Pull Request để thành viên khác review rồi mới merge.
