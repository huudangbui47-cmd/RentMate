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
  },
  "Smtp": {
    "Host": "",
    "Port": 587,
    "EnableSsl": true,
    "Username": "",
    "Password": "",
    "FromName": "RentMate"
  },
  "Wallet": {
    "BankName": "",
    "BankId": "",
    "AccountNumber": "",
    "AccountName": ""
  }
}
```

- `Smtp` của Api dùng để gửi mã 6 số khi khách quên mật khẩu trên app, điền giống AdminSite (xem bên dưới).
- `Wallet` là tài khoản ngân hàng nhận tiền nạp ví. Để trống vẫn chạy được (app không hiện mã QR, Admin duyệt nạp thủ công). Muốn có QR: `BankId` là mã ngân hàng theo VietQR, ví dụ `VCB`, `MB`, `TCB`; `AccountName` viết in hoa không dấu.

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

Ảnh đồ cho thuê do khách tải lên được lưu trên Api (`RentMate.Api/wwwroot/uploads/items`). AdminSite mặc định lấy ảnh từ `https://localhost:7130`; nếu Api chạy ở địa chỉ khác thì thêm `"ApiBaseUrl": "https://dia-chi-api"` vào file trên.

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

Mỗi lần pull code mới có migration mới (thư mục `RentMate.Data/Migrations`) thì chạy lại lệnh này. Nếu Visual Studio đang chạy Api và báo lỗi file bị khóa, thêm `--configuration Migrate` vào cuối lệnh.

Chưa có lệnh `dotnet ef` thì cài: `dotnet tool install --global dotnet-ef`

## 4. Chạy

Mở `RentMate.sln`, chuột phải Solution → Configure Startup Projects → Multiple startup projects → chọn Start cho `RentMate.AdminSite` và `RentMate.Api` → F5.

- Trang quản trị: https://localhost:7140 (đăng nhập bằng tài khoản trong `SeedAdmin`)
- API: https://localhost:7130/swagger

Mỗi lần pull code mới thì chạy lại bước 3.

## 5. Đưa ảnh vào máy ảo Android (để test đăng ảnh đồ cho thuê)

Máy ảo gần như không có ảnh sẵn. Dùng file `rentmate_mobile/tools/gui-anh-vao-may-ao.bat`:

1. Mở máy ảo trước.
2. Chọn ảnh trong File Explorer (chọn nhiều ảnh hoặc cả thư mục cũng được), kéo thả lên file `gui-anh-vao-may-ao.bat`.
3. Đợi cửa sổ đen báo "Xong!" rồi vào app → Thêm ảnh → Chọn từ thư viện.

Ảnh được chép vào `Pictures/RentMate` trên máy ảo và hiện ngay trong thư viện ảnh.

Muốn kéo thả từ Desktop cho tiện: chuột phải file `.bat` → Show more options → Send to → Desktop (create shortcut), rồi kéo ảnh thả lên shortcut đó.
