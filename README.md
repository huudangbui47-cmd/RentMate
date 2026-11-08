# RentMate

Hệ thống cho thuê đồ gồm **API cho app Flutter** và **trang quản trị web**.
Công nghệ: ASP.NET Core 8, SQL Server, EF Core 8, ASP.NET Identity, JWT (API) / Cookie (Admin), theme quản trị Mazer.

## Kiến trúc

Cấu trúc giống project EcommerceManagement: 5 project nằm cùng cấp trong solution.

```
RentMate.sln
├── RentMate.AdminSite   Web quản trị MVC (Cookie, Area "Management", role Admin và Manager)
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
| Trang quản trị mới | Controller có `[Area("Management")]`, `[Authorize(Roles = "Admin,Manager")]` (hoặc chỉ `"Admin"` nếu là chức năng riêng của Admin), kế thừa `ManagementControllerBase`; view trong `Areas/Management/Views/<Tên>/` |
| Ghi nhật ký thao tác admin | Gọi `IAuditLogService.RecordAsync(...)` trước `SaveChangesAsync()`, thêm tên hiển thị vào `ActionText` của `AuditLogItemViewModel` |

> Các entity dùng thuộc tính `Id` (từ `BaseEntity`), nhưng cột trong DB vẫn giữ tên cũ (`CategoryId`, `ItemId`, ...) nhờ `HasColumnName` trong Configurations. DTO trả cho app vẫn giữ tên `CategoryId`, `ItemId`, ... như trước.

## Cài đặt sau khi clone

Xem hướng dẫn từng bước (cài phần mềm, lấy code, tạo file cấu hình, cấu hình Gmail, tạo database, chạy, xử lý lỗi):
**[docs/HUONG-DAN-CAI-DAT.md](docs/HUONG-DAN-CAI-DAT.md)**

Tóm tắt:
1. Tạo `RentMate.Api/appsettings.Development.json` và `RentMate.AdminSite/appsettings.Development.json` (không có trên GitHub).
2. `dotnet ef database update --project RentMate.Data --startup-project RentMate.Api`
3. Mở `RentMate.sln`, chạy AdminSite (https://localhost:7140) và Api (https://localhost:7130/swagger).

## Trang quản trị

| Mục | Chức năng | Quyền |
|---|---|---|
| Tổng quan | Số liệu người dùng / đồ / đơn, doanh thu 6 tháng, đơn mới nhất, đồ được thuê nhiều | Admin, Manager |
| Đơn thuê | Lọc theo trạng thái, tìm theo mã/tên; xem chi tiết tiến trình, thanh toán, biên bản tình trạng | Admin, Manager |
| Đồ cho thuê | Lọc theo danh mục/trạng thái; tạm ngưng, ẩn hoặc mở lại đồ | Admin, Manager |
| Danh mục | Thêm, sửa (modal), ngừng/mở lại hoạt động, xóa (chỉ khi chưa có đồ) | Admin, Manager |
| Thanh toán | Lọc theo trạng thái/loại/ngày, tổng tiền đã thu | Admin, Manager |
| Khách hàng | Thêm (sinh mật khẩu tạm), sửa (modal), đặt lại mật khẩu, khóa/mở khóa (không cho khóa khi còn đơn chưa xong). Không có xóa | Admin, Manager |
| Tài khoản quản lý | Thêm, sửa, khóa/mở khóa Manager; chỉ xóa được Manager chưa từng thao tác | Admin |
| Nhật ký hệ thống | Lịch sử đăng nhập và thao tác; mỗi lần lưu ghi 1 dòng kèm các thay đổi | Admin |
| Thông tin tài khoản | Sửa họ tên, email, SĐT, ảnh đại diện; đổi mật khẩu | Admin, Manager |
| Quên mật khẩu | Gửi link đặt lại mật khẩu (hết hạn 30 phút, dùng 1 lần) về email | Admin, Manager |

Giao diện dựa trên layout, CSS và JS của project EcommerceManagement (theme [Mazer](https://github.com/zuramai/mazer), MIT). Thư viện được đặt sẵn trong `RentMate.AdminSite/wwwroot/lib`, không phụ thuộc CDN. Chỉnh giao diện riêng cho RentMate thì sửa ở `wwwroot/css/rentmate.css`.

## Quy trình làm việc nhóm
- Không push thẳng lên `main`.
- Mỗi việc làm trên một nhánh riêng: `feature/...`, `fix/...`, `docs/...`
- Commit theo dạng: `feat: ...`, `fix: ...`, `refactor: ...`, `docs: ...`, `chore: ...`
- Làm xong thì mở Pull Request để thành viên khác review rồi mới merge.
