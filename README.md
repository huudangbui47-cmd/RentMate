# RentMate API

ASP.NET Core Web API cho ứng dụng RentMate (SQL Server + EF Core + JWT).

## Cài đặt sau khi clone

### 1. Tạo file cấu hình
File `appsettings.json` và `appsettings.Development.json` không được đưa lên GitHub.
Tạo file `appsettings.Development.json` ở thư mục gốc project với nội dung:

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

- `Jwt:Key` phải dài ít nhất 32 ký tự.
- Nếu không dùng LocalDB, sửa phần `Server=` cho phù hợp với SQL Server trên máy.

### 2. Tạo database
Visual Studio → Tools → NuGet Package Manager → Package Manager Console:

```
Update-Database
```

### 3. Chạy
Bấm F5, trình duyệt sẽ mở Swagger.

## Quy trình làm việc nhóm
- Không push thẳng lên `main`.
- Mỗi việc làm trên một nhánh riêng: `feature/...`, `fix/...`, `docs/...`
- Commit theo dạng: `feat: ...`, `fix: ...`, `refactor: ...`, `docs: ...`, `chore: ...`
- Làm xong thì mở Pull Request để thành viên khác review rồi mới merge.