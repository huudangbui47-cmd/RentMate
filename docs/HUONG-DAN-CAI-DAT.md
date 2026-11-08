# Hướng dẫn chạy RentMate

## 1. Lấy code

Chưa có project:
```
git clone https://github.com/huudangbui47-cmd/RentMate.git
cd RentMate
git checkout feature/sua-kien-truc-them-giao-dien
```

Đã có project (mở terminal trong thư mục RentMate):
```
git stash
git fetch
git checkout feature/sua-kien-truc-them-giao-dien
git pull
```

## 2. Tạo 2 file cấu hình

Hai file này không có trên GitHub nên phải tự tạo.

`RentMate.Api/appsettings.Development.json`
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\MSSQLLocalDB;Database=RentMateDb;Trusted_Connection=True;TrustServerCertificate=True"
  },
  "Jwt": {
    "Key": "rentmate-dev-secret-key-at-least-32-characters!!",
    "Issuer": "RentMate",
    "Audience": "RentMateClient"
  }
}
```

`RentMate.AdminSite/appsettings.Development.json`
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\MSSQLLocalDB;Database=RentMateDb;Trusted_Connection=True;TrustServerCertificate=True"
  },
  "SeedAdmin": {
    "Email": "email-cua-ban@gmail.com",
    "Password": "Admin@123",
    "FullName": "Quản trị viên"
  },
  "Smtp": {
    "Host": "",
    "Port": 587,
    "EnableSsl": true,
    "Username": "",
    "Password": "",
    "FromName": "RentMate"
  }
}
```

Smtp để trống vẫn chạy được, khi đó link quên mật khẩu được in ra console (đổi `&amp;` thành `&` trước khi dán vào trình duyệt).

Muốn gửi mail thật qua Gmail:
1. Bật Xác minh 2 bước tại https://myaccount.google.com/security
2. Tạo App Password tại https://myaccount.google.com/apppasswords, chép mã 16 ký tự
3. Điền vào mục `Smtp`:
```json
"Smtp": {
  "Host": "smtp.gmail.com",
  "Port": 587,
  "EnableSsl": true,
  "Username": "gmail-cua-ban@gmail.com",
  "Password": "maapppassword16kytu",
  "FromName": "RentMate"
}
```
`Password` là mã App Password viết liền, không phải mật khẩu Gmail. Sửa xong phải chạy lại AdminSite.

## 3. Tạo database

Chạy ở thư mục gốc RentMate:
```
dotnet ef database update --project RentMate.Data --startup-project RentMate.Api
```

Chưa có lệnh `dotnet ef` thì cài: `dotnet tool install --global dotnet-ef`

## 4. Chạy

Mở `RentMate.sln`, chuột phải Solution → Configure Startup Projects → Multiple startup projects → chọn Start cho `RentMate.AdminSite` và `RentMate.Api` → F5.

- Trang quản trị: https://localhost:7140 (đăng nhập bằng tài khoản trong `SeedAdmin`)
- API: https://localhost:7130/swagger

Mỗi lần pull code mới thì chạy lại bước 3.
