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
  },
  "Ai": {
    "ApiKey": "",
    "Model": "claude-opus-5-5"
  },
  "VnPay": {
    "TmnCode": "",
    "HashSecret": "",
    "ReturnUrl": "http://10.0.2.2:5076/api/payments/vnpay-return"
  },
  "Ghn": {
    "Token": "",
    "ShopId": 0
  },
  "Cloudinary": {
    "CloudName": "",
    "ApiKey": "",
    "ApiSecret": ""
  }
}
```

- `Cloudinary`: nơi lưu ảnh (ảnh đồ, ảnh đại diện, ảnh biên bản) trên mạng thay vì ổ cứng máy chạy Api, để cả nhóm và điện thoại thật đều xem được cùng một ảnh. Đăng ký miễn phí ở https://cloudinary.com, vào Dashboard lấy **Cloud name**, **API Key**, **API Secret**. Để trống `CloudName` thì ảnh vẫn lưu ổ cứng (`RentMate.Api/wwwroot/uploads`) như cũ. Ảnh cũ dạng `/uploads/...` vẫn hiện bình thường sau khi bật.
- `VnPay`: nạp ví qua cổng VNPay **sandbox** (tiền ảo). Đăng ký miễn phí ở https://sandbox.vnpayment.vn/devreg/, VNPay gửi `TmnCode` và `HashSecret` qua email. Thẻ test: ngân hàng **NCB**, số thẻ `9704198526191432198`, tên `NGUYEN VAN A`, ngày phát hành `07/15`, OTP `123456`. Để trống thì app chỉ có nạp bằng chuyển khoản thủ công.
  - `ReturnUrl` là địa chỉ VNPay chuyển về sau khi thanh toán; máy ảo Android giữ nguyên `10.0.2.2`, điện thoại thật thì đổi thành IP LAN của máy chạy Api (vd. `http://192.168.1.10:5076/...`).
- `Ghn`: giao hàng qua Giao Hàng Nhanh, môi trường thử. Đăng ký tài khoản ở https://5sao.ghn.dev, tạo một cửa hàng (địa chỉ cửa hàng = nơi shipper đến lấy hàng), rồi lấy **Token** (mục Chủ cửa hàng → Xem) và **ShopId**. Để trống thì app chỉ có "Gặp trực tiếp".
  - Ở môi trường thử, vận đơn tạo được nhưng **không có shipper thật**, trạng thái thường đứng ở "Chờ lấy hàng". Người thuê vẫn bấm "Đã nhận đồ" bình thường để đi tiếp.
- `AdminSite` cũng cần mục `Ghn` (giống Api) để hủy vận đơn khi đơn bị hủy; không có thì bỏ qua.

- `Ai`: AI (Claude) xem ảnh biên bản lúc giao/nhận lại, ghi khuyết điểm và gợi ý mức trừ cọc. Lấy khóa ở https://console.anthropic.com → API Keys (cần nạp credit). Để trống `ApiKey` thì biên bản vẫn lưu bình thường, chỉ không có phần nhận xét AI. Mỗi lần so sánh tốn khoảng vài nghìn đồng.
- `Smtp` của Api dùng để gửi mã 6 số khi khách quên mật khẩu trên app, điền giống AdminSite (xem bên dưới).
- `Wallet` là tài khoản ngân hàng nhận tiền nạp ví. **Nên nhập ở trang quản trị → Cài đặt hệ thống** thay vì ở đây; mục này chỉ còn dùng khi trang Cài đặt để trống. Muốn có QR: `BankId` là mã ngân hàng theo VietQR, ví dụ `VCB`, `MB`, `TCB`; `AccountName` viết in hoa không dấu.

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
  },
  "Ai": {
    "ApiKey": "",
    "Model": "claude-opus-5-5"
  },
  "Ghn": {
    "Token": "",
    "ShopId": 0
  },
  "Cloudinary": {
    "CloudName": "",
    "ApiKey": "",
    "ApiSecret": ""
  }
}
```

- `Cloudinary` ở AdminSite: điền **giống hệt Api** để ảnh đại diện quản trị và banner trang chủ cũng lưu lên Cloudinary (không nằm trong project). Để trống thì lưu ổ cứng như cũ.
- `Ai` ở AdminSite dùng cho nút "Dịch bằng AI" trên trang Ngôn ngữ (cùng khóa với Api). Để trống thì vẫn dịch tay được.

Ảnh đồ cho thuê do khách tải lên được lưu trên Cloudinary (nếu Api có cấu hình `Cloudinary`, link `https://res.cloudinary.com/...` hiện thẳng) hoặc trên Api (`RentMate.Api/wwwroot/uploads/items`). AdminSite mặc định lấy ảnh từ `https://localhost:7130`; nếu Api chạy ở địa chỉ khác thì thêm `"ApiBaseUrl": "https://dia-chi-api"` vào file trên.

Ảnh quản trị viên tải lên cho app (banner trang chủ) được lưu ở thư mục dùng chung `shared-uploads` nằm cạnh các project (tự tạo khi chạy, đã gitignore); Api và AdminSite cùng phục vụ thư mục này tại `/shared/...`. Muốn để chỗ khác thì thêm `"Storage": { "SharedRoot": "D:\\RentMateUploads" }` vào **cả hai** file cấu hình, trỏ về cùng một thư mục.

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

## 6. Thử API bằng Postman

File nằm trong `docs/postman/`:

1. Mở Postman → **Import** → chọn cả 2 file `RentMate.postman_collection.json` và `RentMate.local.postman_environment.json`.
2. Góc trên bên phải chọn environment **RentMate local** (`baseUrl = http://localhost:5076`).
3. Bấm vào collection **RentMate API** → tab **Variables** → sửa `ownerEmail/ownerPassword` (chủ đồ) và `renterEmail/renterPassword` (người thuê) thành 2 tài khoản khách của bạn. Chưa có thì chạy 2 request "Đăng ký".
4. Chạy "Đăng nhập chủ đồ" và "Đăng nhập người thuê": token tự lưu, các request sau tự dùng.
5. Chạy từng thư mục từ trên xuống. `itemId`, `rentalId`, `depositId` tự lưu sau mỗi bước tạo.

Hai bước phải làm trên trang quản trị: **duyệt đồ** (sau "Đăng đồ mới") và **duyệt nạp tiền** (sau "Tạo yêu cầu nạp").
Request tải ảnh: tab **Body** → chọn file cho key `files`.


## Những thứ quản trị viên tự chỉnh, không cần sửa code

- **Cài đặt hệ thống** (chỉ Admin): phí nền tảng %, hạn mức nạp/rút, số ngày thuê tối đa, đặt trước tối đa, hạn thanh toán, hạn kiểm tra đồ, hạn phản hồi bồi thường, số ảnh tối đa, tài khoản nhận tiền nạp ví, số điện thoại/email hỗ trợ. Lưu xong app áp dụng trong vòng 30 giây (app lấy lại khi mở). Đổi phí chỉ áp dụng cho đơn đặt sau đó.
- **Danh mục**: chọn icon hiện trên app cho từng danh mục.
- **Banner trang chủ**: tải ảnh ngang lên (JPG/PNG tối đa 5MB), ẩn/hiện, đổi thứ tự. App cho các ảnh đang hiện chạy lần lượt ở đầu Trang chủ; chưa có ảnh thì dùng nền tối.
- **Ngôn ngữ**: câu chữ của app tự được nạp khi AdminSite khởi động (có sẵn bản tiếng Anh). Bấm **Thêm ngôn ngữ**, chọn trong danh sách (Trung, Nhật, Hàn, Pháp...), tích **Dùng AI dịch toàn bộ app** → khoảng 1-2 phút sau ngôn ngữ hiện trên app. Không có khóa AI thì phải dịch tay từng câu.
  - Muốn dịch một thông báo lỗi từ máy chủ: vào **Xem / sửa bản dịch** → **Thêm câu** với đúng nguyên văn tiếng Việt.
