using System.Data;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Rentals;
using RentMate.Service.DTOs.Settings;
using RentMate.Service.DTOs.Shipping;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class RentalService : IRentalService
    {
        // Phí nền tảng trừ trên tiền thuê lúc hoàn tất (không tính trên tiền cọc).
        // Tỉ lệ phí lưu trong từng đơn (Rental.PlatformFeeRate) theo cài đặt lúc đặt đơn.
        // Phần chủ đồ nhận và phần RentMate giữ lại của một đơn (Dashboard dùng để tính doanh thu)
        public static decimal OwnerIncome(decimal totalPrice, decimal feeRate) => Math.Round(totalPrice * (1 - feeRate), 0);

        public static decimal PlatformFee(decimal totalPrice, decimal feeRate) => totalPrice - OwnerIncome(totalPrice, feeRate);

        // 0.05 → "5%", 0.025 → "2,5%"
        public static string FeeText(decimal feeRate) => (feeRate * 100).ToString("0.##", System.Globalization.CultureInfo.GetCultureInfo("vi-VN")) + "%";

        // Giới hạn đơn thuê, hạn thanh toán, hạn kiểm tra... lấy từ cài đặt hệ thống (ISystemSettingService)

        private readonly IUnitOfWork _unitOfWork;
        private readonly IWalletService _walletService;
        private readonly INotificationService _notificationService;
        private readonly IAuditLogService _auditLogService;

        private readonly IShippingService _shippingService;
        private readonly ISystemSettingService _settingService;

        public RentalService(IUnitOfWork unitOfWork, IWalletService walletService, INotificationService notificationService, IAuditLogService auditLogService, IShippingService shippingService, ISystemSettingService settingService)
        {
            _settingService = settingService;
            _shippingService = shippingService;
            _unitOfWork = unitOfWork;
            _walletService = walletService;
            _notificationService = notificationService;
            _auditLogService = auditLogService;
        }

        // =========================
        // CREATE RENTAL REQUEST
        // =========================
        public async Task<RentalDto> CreateAsync(
            CreateRentalDto dto,
            string renterId)
        {
            if (dto.StartDate.Date < DateTime.UtcNow.Date)
            {
                throw new ArgumentException(
                    "Ngày bắt đầu thuê không được ở trong quá khứ.");
            }

            if (dto.EndDate.Date < dto.StartDate.Date)
            {
                throw new ArgumentException(
                    "Ngày trả phải sau hoặc trùng ngày nhận.");
            }

            var settings = await _settingService.GetAsync();

            if (dto.StartDate.Date > DateTime.UtcNow.Date.AddDays(settings.MaxDaysAhead))
            {
                throw new ArgumentException(
                    $"Chỉ đặt thuê trước tối đa {settings.MaxDaysAhead} ngày.");
            }

            var numberOfDays =
                (dto.EndDate.Date - dto.StartDate.Date).Days + 1;

            if (numberOfDays > settings.MaxRentalDays)
            {
                throw new ArgumentException(
                    $"Mỗi đơn thuê tối đa {settings.MaxRentalDays} ngày.");
            }

            var item = await _unitOfWork.Items
                .BuildQuery(i => i.Id == dto.ItemId)
                .FirstOrDefaultAsync();

            // Chỉ thuê được đồ đã duyệt (đang trống hoặc đang có người thuê thì đặt lịch khác)
            if (item == null ||
                (item.Status != ItemStatus.Available && item.Status != ItemStatus.Rented))
            {
                throw new ArgumentException(
                    "Đồ không tồn tại hoặc hiện không cho thuê.");
            }

            // Không được thuê đồ của chính mình
            if (item.OwnerId == renterId)
            {
                throw new InvalidOperationException(
                    "Bạn không thể thuê đồ của chính mình.");
            }

            // Mỗi người chỉ có một yêu cầu đang mở cho cùng một món đồ (chống gửi trùng/spam)
            var hasOpenRequest = await _unitOfWork.Rentals
                .BuildQuery(r =>
                    r.ItemId == item.Id &&
                    r.RenterId == renterId &&
                    (r.Status == RentalStatus.Pending ||
                     r.Status == RentalStatus.Approved ||
                     r.Status == RentalStatus.WaitingForPickup))
                .AnyAsync();

            if (hasOpenRequest)
            {
                throw new InvalidOperationException(
                    "Bạn đã có một đơn thuê món đồ này đang xử lý. Hãy xem trong mục Đơn thuê.");
            }

            // Ngày đã có người thuê chắc chắn thì báo ngay, không đợi chủ đồ duyệt mới biết
            var startDate = dto.StartDate.Date;
            var endDate = dto.EndDate.Date;

            var busy = await _unitOfWork.Rentals
                .BuildQuery(r =>
                    r.ItemId == item.Id &&
                    (r.Status == RentalStatus.Approved ||
                     r.Status == RentalStatus.WaitingForPickup ||
                     r.Status == RentalStatus.Rented) &&
                    startDate <= r.EndDate &&
                    endDate >= r.StartDate)
                .OrderBy(r => r.StartDate)
                .Select(r => new { r.StartDate, r.EndDate })
                .FirstOrDefaultAsync();

            if (busy != null)
            {
                throw new InvalidOperationException(
                    $"Đồ đã có người thuê từ {busy.StartDate:dd/MM} đến {busy.EndDate:dd/MM}. Vui lòng chọn ngày khác.");
            }

            if (!Enum.IsDefined(typeof(DeliveryMethod), dto.DeliveryMethod))
            {
                throw new ArgumentException("Cách nhận đồ không hợp lệ.");
            }

            bool ship = dto.DeliveryMethod == DeliveryMethod.Ghn;

            if (ship)
            {
                if (!_shippingService.IsEnabled)
                {
                    throw new InvalidOperationException("Giao hàng GHN chưa được bật, vui lòng chọn nhận đồ trực tiếp.");
                }

                var phone = dto.ShipToPhone?.Trim() ?? "";

                if (string.IsNullOrWhiteSpace(dto.ShipToName) ||
                    string.IsNullOrWhiteSpace(dto.ShipToAddress) ||
                    string.IsNullOrWhiteSpace(dto.ShipToWardCode) ||
                    dto.ShipToDistrictId is null or <= 0)
                {
                    throw new ArgumentException("Vui lòng nhập đủ tên người nhận, địa chỉ và chọn tỉnh, quận, phường.");
                }

                if (phone.Length < 10 || phone.Length > 11 || !phone.All(char.IsDigit) || phone[0] != '0')
                {
                    throw new ArgumentException("Số điện thoại người nhận không hợp lệ.");
                }
            }

            int discountPercent = item.DiscountPercent > 0 && numberOfDays >= item.DiscountMinDays
                ? item.DiscountPercent
                : 0;
            decimal discountAmount = Math.Round(item.PricePerDay * numberOfDays * discountPercent / 100m, 0);

            var rental = new Rental
            {
                PlatformFeeRate = settings.PlatformFeeRate,
                ItemId = item.Id,
                RenterId = renterId,

                DeliveryMethod = dto.DeliveryMethod,
                ShipToName = ship ? Cut(dto.ShipToName!.Trim(), 100) : null,
                ShipToPhone = ship ? dto.ShipToPhone!.Trim() : null,
                ShipToAddress = ship ? Cut(dto.ShipToAddress!.Trim(), 300) : null,
                ShipToDistrictId = ship ? dto.ShipToDistrictId : null,
                ShipToWardCode = ship ? dto.ShipToWardCode!.Trim() : null,
                ShipToAreaText = ship ? Cut(dto.ShipToAreaText?.Trim() ?? "", 300) : null,

                StartDate = dto.StartDate.Date,
                EndDate = dto.EndDate.Date,

                // Giữ giá tại thời điểm tạo đơn
                PricePerDay = item.PricePerDay,
                DepositAmount = item.DepositAmount,

                // Ưu đãi thuê dài ngày của chủ đồ, làm tròn tới đồng
                DiscountPercent = discountPercent,
                DiscountAmount = discountAmount,

                TotalPrice =
                    item.PricePerDay * numberOfDays - discountAmount,

                RequestNote = dto.RequestNote,

                Status = RentalStatus.Pending,

                RequestedAt = DateTime.UtcNow
            };

            await _unitOfWork.Rentals.AddAsync(rental);

            await _notificationService.AddAsync(item.OwnerId, NotificationType.RentalRequest,
                "Có yêu cầu thuê mới",
                $"Có người muốn thuê '{item.ItemName}' từ {rental.StartDate:dd/MM} đến {rental.EndDate:dd/MM}. Vào Đơn thuê để duyệt.");

            await _unitOfWork.SaveChangesAsync();

            var result =
                await GetRentalDtoAsync(rental.Id);

            return result!;
        }

        // =========================
        // GET MY RENTALS
        // =========================
        public async Task<List<RentalDto>> GetMyRentalsAsync(
            string userId)
        {
            var rentals = await RentalQuery()
                .Where(r =>
                    r.RenterId == userId ||
                    r.Item.OwnerId == userId)
                .OrderByDescending(r => r.RequestedAt)
                .ToListAsync();

            var settings = await _settingService.GetAsync();

            return rentals
                .Select(r => ToDto(r, settings))
                .ToList();
        }

        // =========================
        // GET RENTAL DETAIL
        // =========================
        public async Task<RentalDto?> GetByIdAsync(
            int rentalId,
            string userId)
        {
            var rental = await RentalQuery()
                .FirstOrDefaultAsync(r =>
                    r.Id == rentalId &&
                    (
                        r.RenterId == userId ||
                        r.Item.OwnerId == userId
                    ));

            if (rental == null)
            {
                return null;
            }

            return ToDto(rental, await _settingService.GetAsync());
        }

        // =========================
        // APPROVE
        // =========================
        public Task<bool> ApproveAsync(int rentalId, string ownerId) =>
            RunSeriallyAsync(() => ApproveCoreAsync(rentalId, ownerId));

        private async Task<bool> ApproveCoreAsync(
            int rentalId,
            string ownerId)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

            if (rental == null)
            {
                return false;
            }

            if (rental.Item.OwnerId != ownerId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.Status != RentalStatus.Pending)
            {
                throw new InvalidOperationException(
                    "Chỉ duyệt được đơn đang chờ duyệt.");
            }

            // Chỉ đồ đang hiện trên app (trống hoặc đang có người thuê) mới duyệt được.
            // Đồ bị ẩn, tạm ngưng, chờ duyệt lại sau khi sửa hoặc bị từ chối thì chặn.
            if (!IsRentable(rental.Item.Status))
            {
                throw new InvalidOperationException(
                    "Đồ đang bị ẩn, tạm ngưng hoặc chờ quản lý duyệt lại, chưa duyệt đơn được.");
            }

            // Kiểm tra lịch thuê trùng
            var hasConflict = await _unitOfWork.Rentals
                .BuildQuery(r =>
                    r.Id != rentalId &&
                    r.ItemId == rental.ItemId &&

                    (
                        r.Status == RentalStatus.Approved ||
                        r.Status == RentalStatus.WaitingForPickup ||
                        r.Status == RentalStatus.Rented
                    ) &&

                    rental.StartDate <= r.EndDate &&
                    rental.EndDate >= r.StartDate)
                .AnyAsync();

            if (hasConflict)
            {
                throw new InvalidOperationException(
                    "Đồ đã có người thuê trong khoảng thời gian này.");
            }

            rental.Status = RentalStatus.Approved;
            rental.ApprovedAt = DateTime.UtcNow;

            await _notificationService.AddAsync(rental.RenterId, NotificationType.RentalApproved,
                "Đơn thuê đã được đồng ý",
                $"Chủ đồ đã đồng ý cho thuê '{rental.Item.ItemName}'. Hãy thanh toán trong 24 giờ để giữ lịch.");

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // REJECT
        // =========================
        public async Task<bool> RejectAsync(
            int rentalId,
            string ownerId)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

            if (rental == null)
            {
                return false;
            }

            if (rental.Item.OwnerId != ownerId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.Status != RentalStatus.Pending)
            {
                throw new InvalidOperationException(
                    "Chỉ từ chối được đơn đang chờ duyệt.");
            }

            rental.Status = RentalStatus.Rejected;

            await _notificationService.AddAsync(rental.RenterId, NotificationType.RentalRejected,
                "Đơn thuê bị từ chối",
                $"Chủ đồ đã từ chối yêu cầu thuê '{rental.Item.ItemName}'. Bạn có thể tìm món đồ khác trên trang Khám phá.");

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // PICKUP (người thuê xác nhận đã nhận đồ = đồng ý biên bản lúc giao)
        // =========================
        public Task<bool> PickupAsync(int rentalId, string renterId) =>
            RunSeriallyAsync(() => PickupCoreAsync(rentalId, renterId));

        private async Task<bool> PickupCoreAsync(
            int rentalId,
            string renterId)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

            if (rental == null)
            {
                return false;
            }

            // Người nhận đồ xác nhận, không để chủ đồ tự bấm "đã giao" khi chưa đưa đồ
            if (rental.RenterId != renterId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.Status != RentalStatus.WaitingForPickup)
            {
                throw new InvalidOperationException(
                    "Chỉ xác nhận nhận đồ được khi đơn đã thanh toán và chưa nhận.");
            }

            // Người thuê phải tự chụp ảnh lúc nhận (biên bản này chỉ lập được sau biên bản lúc giao của chủ đồ)
            var hasRenterReport = await _unitOfWork.ConditionReports
                .BuildQuery(c =>
                    c.RentalId == rentalId &&
                    c.ReportType == ConditionReportType.RenterReceived)
                .AnyAsync();

            if (!hasRenterReport)
            {
                throw new InvalidOperationException(
                    "Hãy chụp ảnh biên bản lúc nhận đồ (nút Biên bản) trước khi bấm Đã nhận đồ.");
            }

            var now = DateTime.UtcNow;

            rental.Status = RentalStatus.Rented;
            rental.ReceivedAt = now;

            string shiftNote = await ApplyLateDeliveryAsync(rental, now);

            if (shiftNote.Length > 0)
            {
                await _notificationService.AddAsync(rental.RenterId, NotificationType.System,
                    "Đã tính lại ngày thuê", $"Đơn #{rental.Id} '{rental.Item.ItemName}':{shiftNote}");
            }

            // Không ghi đè khi đồ đang bị ẩn/chờ duyệt lại
            if (rental.Item.Status == ItemStatus.Available)
            {
                rental.Item.Status = ItemStatus.Rented;
            }

            await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.System,
                "Người thuê đã nhận đồ",
                $"Đơn #{rental.Id} '{rental.Item.ItemName}': người thuê đã nhận đồ và đồng ý biên bản lúc giao. Hạn trả {rental.EndDate:dd/MM/yyyy}.{shiftNote}");

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // RETURN
        // =========================
        public async Task<bool> ReturnAsync(
            int rentalId,
            string renterId)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

            if (rental == null)
            {
                return false;
            }

            if (rental.RenterId != renterId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.Status != RentalStatus.Rented)
            {
                throw new InvalidOperationException(
                    "Chỉ trả được đồ đang thuê.");
            }

            rental.Status = RentalStatus.Returned;
            rental.ReturnedAt = DateTime.UtcNow;

            var settings = await _settingService.GetAsync();

            await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.ReturnReminder,
                "Người thuê đã trả đồ",
                $"Đơn #{rental.Id} '{rental.Item.ItemName}': trong {settings.OwnerInspectionDays} ngày, hãy chụp ảnh lập biên bản nhận lại (AI so sánh với lúc giao) rồi bấm Hoàn tất.");

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // COMPLETE / BỒI THƯỜNG / KHIẾU NẠI
        // =========================

        // Chủ đồ: không trừ cọc thì hoàn tất ngay; có trừ cọc thì chờ người thuê đồng ý hoặc khiếu nại.
        // Chủ đồ quá 3 ngày không kiểm tra: người thuê được tự hoàn tất và nhận đủ cọc.
        // Người thuê quá 2 ngày không phản hồi bồi thường: chủ đồ được chốt mức đã đề nghị.
        public Task<bool> CompleteAsync(int rentalId, string userId, decimal damageAmount, string? damageNote) =>
            RunSeriallyAsync(() => CompleteCoreAsync(rentalId, userId, damageAmount, damageNote));

        private async Task<bool> CompleteCoreAsync(
            int rentalId,
            string userId,
            decimal damageAmount,
            string? damageNote)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

            if (rental == null)
            {
                return false;
            }

            bool isOwner = rental.Item.OwnerId == userId;
            bool isRenter = rental.RenterId == userId;

            if (!isOwner && !isRenter)
            {
                throw new UnauthorizedAccessException();
            }

            var now = DateTime.UtcNow;
            var settings = await _settingService.GetAsync();

            if (isRenter)
            {
                if (rental.Status != RentalStatus.Returned)
                {
                    throw new InvalidOperationException(
                        "Chỉ tự hoàn tất được khi đã trả đồ mà chủ đồ chưa xử lý.");
                }

                var deadline = (rental.ReturnedAt ?? now).AddDays(settings.OwnerInspectionDays);

                if (now < deadline)
                {
                    throw new InvalidOperationException(
                        $"Chủ đồ có {settings.OwnerInspectionDays} ngày để kiểm tra đồ. Bạn tự hoàn tất được sau {deadline.ToLocalTime():dd/MM HH:mm}.");
                }

                await SettleAsync(rental, 0,
                    $"Chủ đồ không kiểm tra đồ trong {settings.OwnerInspectionDays} ngày nên đơn tự hoàn tất.");

                return true;
            }

            if (rental.Status == RentalStatus.DamageClaimed)
            {
                var deadline = (rental.DamageClaimedAt ?? now).AddDays(settings.RenterResponseDays);

                if (now < deadline)
                {
                    throw new InvalidOperationException(
                        $"Đang chờ người thuê phản hồi yêu cầu bồi thường (đến {deadline.ToLocalTime():dd/MM HH:mm}).");
                }

                await SettleAsync(rental, rental.DamageAmount,
                    $"Người thuê không phản hồi trong {settings.RenterResponseDays} ngày nên áp dụng mức bồi thường chủ đồ đề nghị.");

                return true;
            }

            if (rental.Status != RentalStatus.Returned)
            {
                throw new InvalidOperationException(
                    "Người thuê chưa trả đồ, chưa hoàn tất được.");
            }

            var hasAfterReport = await _unitOfWork.ConditionReports
                .BuildQuery(c =>
                    c.RentalId == rentalId &&
                    c.ReportType == ConditionReportType.AfterRental)
                .AnyAsync();

            if (!hasAfterReport)
            {
                throw new InvalidOperationException(
                    "Cần chụp ảnh lập biên bản lúc nhận lại đồ trước khi hoàn tất.");
            }

            ValidateDamage(rental, damageAmount);

            if (damageAmount == 0)
            {
                await SettleAsync(rental, 0, null);
                return true;
            }

            damageNote = damageNote?.Trim();

            if (string.IsNullOrEmpty(damageNote))
            {
                throw new InvalidOperationException(
                    "Vui lòng ghi lý do trừ cọc để người thuê biết.");
            }

            rental.Status = RentalStatus.DamageClaimed;
            rental.DamageAmount = damageAmount;
            rental.DamageNote = damageNote.Length > 1000 ? damageNote[..1000] : damageNote;
            rental.DamageClaimedAt = now;

            int responseDays = (await _settingService.GetAsync()).RenterResponseDays;

            await _notificationService.AddAsync(rental.RenterId, NotificationType.Payment,
                "Chủ đồ yêu cầu bồi thường",
                $"Đơn #{rental.Id} '{rental.Item.ItemName}': chủ đồ đề nghị trừ {NotificationService.Money(damageAmount)} tiền cọc. " +
                $"Lý do: {rental.DamageNote}. Vào Đơn thuê để đồng ý hoặc khiếu nại trong {responseDays} ngày.");

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // Người thuê đồng ý mức bồi thường: hoàn tất, trừ cọc
        public Task<bool> AcceptDamageAsync(int rentalId, string renterId) =>
            RunSeriallyAsync(async () =>
            {
                var rental = await GetRentalWithItemAsync(rentalId);

                if (rental == null)
                {
                    return false;
                }

                if (rental.RenterId != renterId)
                {
                    throw new UnauthorizedAccessException();
                }

                if (rental.Status != RentalStatus.DamageClaimed)
                {
                    throw new InvalidOperationException("Đơn này không có yêu cầu bồi thường đang chờ.");
                }

                await SettleAsync(rental, rental.DamageAmount, "Người thuê đã đồng ý mức bồi thường.");

                return true;
            });

        // Người thuê không đồng ý: chuyển quản trị viên phân xử, tiền cọc giữ nguyên tới khi có kết luận
        public Task<bool> DisputeAsync(int rentalId, string renterId, string reason) =>
            RunSeriallyAsync(async () =>
            {
                var rental = await GetRentalWithItemAsync(rentalId);

                if (rental == null)
                {
                    return false;
                }

                if (rental.RenterId != renterId)
                {
                    throw new UnauthorizedAccessException();
                }

                if (rental.Status != RentalStatus.DamageClaimed)
                {
                    throw new InvalidOperationException("Chỉ khiếu nại được khi chủ đồ đang yêu cầu bồi thường.");
                }

                reason = reason?.Trim() ?? string.Empty;

                if (reason.Length == 0)
                {
                    throw new InvalidOperationException("Vui lòng nhập lý do khiếu nại.");
                }

                rental.Status = RentalStatus.Disputed;
                rental.DisputeReason = reason.Length > 1000 ? reason[..1000] : reason;
                rental.DisputedAt = DateTime.UtcNow;

                await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.System,
                    "Người thuê khiếu nại bồi thường",
                    $"Đơn #{rental.Id} '{rental.Item.ItemName}': người thuê không đồng ý trừ cọc. Quản trị viên RentMate sẽ xem ảnh biên bản và phân xử.");

                await _unitOfWork.SaveChangesAsync();

                return true;
            });

        // Quản trị viên phân xử khiếu nại: chốt số tiền trừ cọc (0 → tiền cọc)
        public Task ResolveDisputeAsync(int rentalId, decimal damageAmount, string? note, string adminId, string ipAddress) =>
            RunSeriallyAsync(async () =>
            {
                var rental = await GetRentalWithItemAsync(rentalId)
                    ?? throw new InvalidOperationException("Đơn thuê không tồn tại.");

                if (rental.Status != RentalStatus.Disputed)
                {
                    throw new InvalidOperationException("Đơn này không ở trạng thái khiếu nại (có thể đã được người khác xử lý).");
                }

                ValidateDamage(rental, damageAmount);

                note = note?.Trim();

                if (string.IsNullOrEmpty(note))
                {
                    throw new InvalidOperationException("Vui lòng ghi kết luận để hai bên biết lý do.");
                }

                rental.ResolutionNote = note.Length > 1000 ? note[..1000] : note;

                await _auditLogService.RecordAsync("ResolveDispute", "Rental", rental.Id.ToString(),
                    $"Phân xử khiếu nại đơn #{rental.Id}: trừ {NotificationService.Money(damageAmount)} / cọc {NotificationService.Money(rental.DepositAmount)} (chủ đồ đề nghị {NotificationService.Money(rental.DamageAmount)}). Kết luận: {rental.ResolutionNote}",
                    ipAddress, adminId);

                await SettleAsync(rental, damageAmount, $"Quản trị viên đã phân xử: {rental.ResolutionNote}");

                return true;
            });

        private static void ValidateDamage(Rental rental, decimal damageAmount)
        {
            if (damageAmount < 0 || damageAmount > rental.DepositAmount)
            {
                throw new InvalidOperationException(
                    $"Tiền bồi thường từ 0 đến {NotificationService.Money(rental.DepositAmount)} (không vượt tiền cọc).");
            }
        }

        // Chốt đơn: chủ đồ nhận tiền thuê trừ phí + tiền bồi thường, người thuê nhận lại phần cọc còn lại.
        // Một lần SaveChanges: đổi trạng thái đơn và cộng tiền cùng thành công hoặc cùng thất bại.
        private async Task SettleAsync(Rental rental, decimal damageAmount, string? extraNote)
        {
            rental.Status = RentalStatus.Completed;
            rental.CompletedAt = DateTime.UtcNow;
            rental.DamageAmount = damageAmount;

            // Chỉ trả về "Còn trống" khi đồ đang ở trạng thái "Đang cho thuê";
            // đồ đã bị ẩn hoặc chủ đồ sửa (chờ duyệt lại) thì giữ nguyên, không tự hiện lại trên app
            if (rental.Item.Status == ItemStatus.Rented)
            {
                rental.Item.Status = ItemStatus.Available;
            }

            var ownerIncome = OwnerIncome(rental.TotalPrice, rental.PlatformFeeRate);
            var refund = rental.DepositAmount - damageAmount;

            await AddWalletEntryAsync(
                rental.Item.OwnerId,
                ownerIncome,
                WalletTransactionType.RentalIncome,
                rental.Id,
                $"Tiền thuê đơn #{rental.Id} (đã trừ phí {FeeText(rental.PlatformFeeRate)})");

            if (damageAmount > 0)
            {
                await AddWalletEntryAsync(
                    rental.Item.OwnerId,
                    damageAmount,
                    WalletTransactionType.Compensation,
                    rental.Id,
                    $"Bồi thường hư hỏng đơn #{rental.Id}");

                await AddPaymentAsync(rental.Id, damageAmount, PaymentType.Compensation);
            }

            if (refund > 0)
            {
                await AddWalletEntryAsync(
                    rental.RenterId,
                    refund,
                    WalletTransactionType.DepositRefund,
                    rental.Id,
                    damageAmount > 0
                        ? $"Hoàn cọc đơn #{rental.Id} (đã trừ {NotificationService.Money(damageAmount)} bồi thường)"
                        : $"Hoàn cọc đơn #{rental.Id}");

                await AddPaymentAsync(rental.Id, refund, PaymentType.DepositRefund);
            }

            string suffix = string.IsNullOrEmpty(extraNote) ? "" : " " + extraNote;

            await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.Payment,
                "Bạn nhận được tiền thuê",
                $"Đơn #{rental.Id} '{rental.Item.ItemName}' đã hoàn tất. {NotificationService.Money(ownerIncome)} tiền thuê (đã trừ phí {FeeText(rental.PlatformFeeRate)})" +
                (damageAmount > 0 ? $" và {NotificationService.Money(damageAmount)} tiền bồi thường" : "") +
                " đã được cộng vào ví." + suffix);

            await _notificationService.AddAsync(rental.RenterId, NotificationType.Payment,
                "Đơn thuê đã hoàn tất",
                (damageAmount > 0
                    ? $"Đơn #{rental.Id} '{rental.Item.ItemName}': trừ {NotificationService.Money(damageAmount)} bồi thường, hoàn {NotificationService.Money(refund)} tiền cọc vào ví."
                    : rental.DepositAmount > 0
                        ? $"Cảm ơn bạn đã thuê '{rental.Item.ItemName}'. Đã hoàn {NotificationService.Money(rental.DepositAmount)} tiền cọc vào ví."
                        : $"Cảm ơn bạn đã thuê '{rental.Item.ItemName}'.") + suffix);

            await _unitOfWork.SaveChangesAsync();
        }

        // =========================
        // PAY (người thuê thanh toán bằng ví)
        // =========================
        public Task<bool> PayAsync(int rentalId, string renterId) =>
            RunSeriallyAsync(() => PayCoreAsync(rentalId, renterId));

        private async Task<bool> PayCoreAsync(
            int rentalId,
            string renterId)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

            if (rental == null)
            {
                return false;
            }

            if (rental.RenterId != renterId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.Status != RentalStatus.Approved)
            {
                throw new InvalidOperationException(
                    "Chỉ thanh toán được đơn đã được chủ đồ duyệt.");
            }

            if (!IsRentable(rental.Item.Status))
            {
                throw new InvalidOperationException(
                    "Đồ đang bị ẩn, tạm ngưng hoặc chờ quản lý duyệt lại, chưa thanh toán được.");
            }

            var amount = rental.TotalPrice + rental.DepositAmount;

            // Đang trong transaction Serializable (RunSeriallyAsync): lệnh trả tiền thứ hai gửi cùng lúc bị chặn lại
            if (await _walletService.GetAvailableBalanceAsync(renterId) < amount)
            {
                throw new InvalidOperationException(
                    "Số dư ví không đủ. Vui lòng nạp thêm tiền.");
            }

            await AddWalletEntryAsync(
                renterId,
                -amount,
                WalletTransactionType.RentalPayment,
                rental.Id,
                $"Thanh toán đơn #{rental.Id} (thuê + cọc)");

            await AddPaymentAsync(rental.Id, rental.TotalPrice, PaymentType.RentalFee);
            await AddPaymentAsync(rental.Id, rental.DepositAmount, PaymentType.Deposit);

            rental.Status = RentalStatus.WaitingForPickup;

            await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.Payment,
                "Người thuê đã thanh toán",
                $"Đơn #{rental.Id} '{rental.Item.ItemName}' đã được thanh toán. Hãy chụp ảnh lập biên bản lúc giao; người thuê xác nhận đã nhận đồ trong app.");

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // CANCEL (trước khi giao đồ)
        // =========================
        public async Task<bool> CancelAsync(int rentalId, string userId, string? reason = null)
        {
            string? orderCode = null;

            var done = await RunSeriallyAsync(async () =>
            {
                var ok = await CancelCoreAsync(rentalId, userId, reason);

                if (ok)
                {
                    orderCode = (await _unitOfWork.Rentals.GetByIdAsync(rentalId))?.ShippingOrderCode;
                }

                return ok;
            });

            // Đã gửi hàng qua GHN thì hủy vận đơn (lỗi chỉ ghi log)
            if (done && orderCode != null)
            {
                await _shippingService.TryCancelOrderAsync(orderCode);
            }

            return done;
        }

        private async Task<bool> CancelCoreAsync(
            int rentalId,
            string userId,
            string? reason)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

            if (rental == null)
            {
                return false;
            }

            var isRenter = rental.RenterId == userId;
            var isOwner = rental.Item.OwnerId == userId;

            if (!isRenter && !isOwner)
            {
                throw new UnauthorizedAccessException();
            }

            if (isRenter)
            {
                // Người thuê hủy được bất cứ lúc nào trước khi nhận đồ
                if (rental.Status != RentalStatus.Pending &&
                    rental.Status != RentalStatus.Approved &&
                    rental.Status != RentalStatus.WaitingForPickup)
                {
                    throw new InvalidOperationException(
                        "Chỉ hủy được đơn trước khi nhận đồ.");
                }
            }
            else
            {
                // Chủ đồ chỉ hủy được đơn đã duyệt mà người thuê không thanh toán sau thời hạn trong cài đặt
                int timeoutHours = (await _settingService.GetAsync()).PaymentTimeoutHours;

                if (rental.Status != RentalStatus.Approved ||
                    rental.ApprovedAt == null ||
                    DateTime.UtcNow - rental.ApprovedAt.Value < TimeSpan.FromHours(timeoutHours))
                {
                    throw new InvalidOperationException(
                        $"Chủ đồ chỉ hủy được đơn đã duyệt mà người thuê chưa thanh toán sau {timeoutHours} giờ.");
                }
            }

            // Đã thanh toán thì hoàn 100% vào ví người thuê
            if (rental.Status == RentalStatus.WaitingForPickup)
            {
                await AddWalletEntryAsync(
                    rental.RenterId,
                    rental.TotalPrice + rental.DepositAmount,
                    WalletTransactionType.Refund,
                    rental.Id,
                    $"Hoàn tiền đơn #{rental.Id} bị hủy");
            }

            bool wasPaid = rental.Status == RentalStatus.WaitingForPickup;

            rental.Status = RentalStatus.Cancelled;
            rental.CancelReason = string.IsNullOrWhiteSpace(reason) ? null : Cut(reason.Trim(), 500);

            // Báo cho bên còn lại
            if (isRenter)
            {
                await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.System,
                    "Đơn thuê đã bị hủy",
                    $"Người thuê đã hủy đơn #{rental.Id} '{rental.Item.ItemName}'." +
                    (rental.CancelReason != null ? $" Lý do: {rental.CancelReason}" : ""));
            }
            else
            {
                await _notificationService.AddAsync(rental.RenterId, NotificationType.System,
                    "Đơn thuê đã bị hủy",
                    $"Chủ đồ đã hủy đơn #{rental.Id} '{rental.Item.ItemName}' vì quá 24 giờ chưa thanh toán." +
                    (wasPaid ? $" Đã hoàn {NotificationService.Money(rental.TotalPrice + rental.DepositAmount)} vào ví." : ""));
            }

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // GIAO HÀNG GHN
        // =========================
        public async Task<bool> CreateShipmentAsync(int rentalId, string ownerId, int weightGram)
        {
            var rental = await GetRentalWithItemAsync(rentalId);

            if (rental == null)
            {
                return false;
            }

            if (rental.Item.OwnerId != ownerId)
            {
                throw new UnauthorizedAccessException();
            }

            if (rental.DeliveryMethod != DeliveryMethod.Ghn)
            {
                throw new InvalidOperationException("Đơn này nhận đồ trực tiếp, không cần tạo đơn giao hàng.");
            }

            if (rental.Status != RentalStatus.WaitingForPickup)
            {
                throw new InvalidOperationException("Chỉ gửi hàng khi người thuê đã thanh toán và chưa nhận đồ.");
            }

            if (rental.ShippingOrderCode != null)
            {
                throw new InvalidOperationException("Đơn giao hàng đã được tạo rồi.");
            }

            var hasBeforeReport = await _unitOfWork.ConditionReports
                .BuildQuery(c => c.RentalId == rentalId && c.ReportType == ConditionReportType.BeforeRental)
                .AnyAsync();

            if (!hasBeforeReport)
            {
                throw new InvalidOperationException("Hãy chụp ảnh biên bản lúc giao trước khi gửi hàng.");
            }

            if (weightGram < 100 || weightGram > 30000)
            {
                throw new ArgumentException("Khối lượng từ 100 g đến 30 kg.");
            }

            var result = await _shippingService.CreateOrderAsync(new ShipmentRequest
            {
                ClientOrderCode = $"RM{rental.Id}-{DateTime.UtcNow:yyMMddHHmmss}",
                ToName = rental.ShipToName ?? "",
                ToPhone = rental.ShipToPhone ?? "",
                ToAddress = rental.ShipToAddress ?? "",
                ToWardCode = rental.ShipToWardCode ?? "",
                ToDistrictId = rental.ShipToDistrictId ?? 0,
                Content = Cut(rental.Item.ItemName, 100),
                Note = $"Đơn thuê RentMate #{rental.Id}",
                WeightGram = weightGram
            });

            rental.ShippingOrderCode = result.OrderCode;
            rental.ShippingFee = result.Fee;
            rental.ShippingCreatedAt = DateTime.UtcNow;
            rental.ExpectedDeliveryAt = result.ExpectedDeliveryAt;

            await _notificationService.AddAsync(rental.RenterId, NotificationType.System,
                "Đồ đã được gửi đi",
                $"Đơn #{rental.Id} '{rental.Item.ItemName}' đã giao cho GHN, mã vận đơn {result.OrderCode}" +
                (result.ExpectedDeliveryAt != null ? $", dự kiến giao {result.ExpectedDeliveryAt.Value.AddHours(7):dd/MM}." : ".") +
                " Ngày thuê tính từ lúc bạn bấm Đã nhận đồ.");

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        public async Task<ShippingTrackingDto?> GetShippingAsync(int rentalId, string userId)
        {
            var rental = await _unitOfWork.Rentals
                .BuildQuery(r => r.Id == rentalId)
                .Include(r => r.Item)
                .Include(r => r.Payments)
                .Include(r => r.ConditionReports)
                .FirstOrDefaultAsync();

            if (rental == null)
            {
                return null;
            }

            if (rental.RenterId != userId && rental.Item.OwnerId != userId)
            {
                throw new UnauthorizedAccessException();
            }

            bool ship = rental.DeliveryMethod == DeliveryMethod.Ghn;

            var dto = new ShippingTrackingDto
            {
                DeliveryMethod = rental.DeliveryMethod.ToString(),
                OrderCode = rental.ShippingOrderCode,
                ShippingFee = rental.ShippingFee,
                ExpectedDeliveryAt = rental.ExpectedDeliveryAt,
                ShipToText = ship
                    ? $"{rental.ShipToName} · {rental.ShipToPhone}\n{rental.ShipToAddress}, {rental.ShipToAreaText}"
                    : null
            };

            var paidAt = rental.Payments.OrderBy(p => p.CreatedAt).Select(p => (DateTime?)p.CreatedAt).FirstOrDefault();
            var report = (ConditionReportType t) => rental.ConditionReports.FirstOrDefault(c => c.ReportType == t);
            var before = report(ConditionReportType.BeforeRental);
            var received = report(ConditionReportType.RenterReceived);

            dto.Steps.Add(new ShippingStepDto { Title = "Người thuê đã thanh toán", Time = paidAt, Done = paidAt != null });
            dto.Steps.Add(new ShippingStepDto
            {
                Title = "Người cho thuê đang chuẩn bị hàng",
                Detail = before != null ? "Đã chụp ảnh biên bản lúc giao" : "Chờ chụp ảnh biên bản lúc giao",
                Time = before?.CreatedAt,
                Done = before != null
            });

            if (ship)
            {
                dto.Steps.Add(new ShippingStepDto
                {
                    Title = "Đã giao cho Giao Hàng Nhanh",
                    Detail = rental.ShippingOrderCode != null ? $"Mã vận đơn {rental.ShippingOrderCode}" : null,
                    Time = rental.ShippingCreatedAt,
                    Done = rental.ShippingOrderCode != null
                });

                if (rental.ShippingOrderCode != null)
                {
                    try
                    {
                        var tracking = await _shippingService.GetTrackingAsync(rental.ShippingOrderCode);
                        dto.StatusText = GhnShippingService.StatusText(tracking.Status);

                        foreach (var (status, time) in tracking.Logs.OrderBy(l => l.Time))
                        {
                            dto.Steps.Add(new ShippingStepDto { Title = GhnShippingService.StatusText(status), Time = time, Done = true });
                        }
                    }
                    catch (InvalidOperationException ex)
                    {
                        dto.Warning = ex.Message;
                    }
                }
            }

            string? receivedDetail = rental.ShiftedDays > 0
                ? $"Đến tay trễ {rental.ShiftedDays} ngày, hạn trả lùi sang {rental.EndDate:dd/MM/yyyy}"
                : rental.LateDeliveryRefund > 0
                    ? $"Đến tay trễ, đã hoàn {NotificationService.Money(rental.LateDeliveryRefund)} tiền thuê"
                    : received != null && rental.ReceivedAt == null ? "Đã chụp ảnh lúc nhận, chờ bấm Đã nhận đồ" : null;

            dto.Steps.Add(new ShippingStepDto
            {
                Title = ship ? "Người thuê đã nhận hàng" : "Hai bên đã giao nhận trực tiếp",
                Detail = receivedDetail,
                Time = rental.ReceivedAt,
                Done = rental.ReceivedAt != null
            });

            if (rental.ReturnedAt != null)
            {
                dto.Steps.Add(new ShippingStepDto { Title = "Người thuê đã trả đồ", Time = rental.ReturnedAt, Done = true });
            }

            if (rental.CompletedAt != null)
            {
                dto.Steps.Add(new ShippingStepDto { Title = "Đơn hoàn tất", Time = rental.CompletedAt, Done = true });
            }

            return dto;
        }

        // Đồ đến tay trễ hơn ngày bắt đầu thuê: lùi hạn trả cho đủ số ngày đã trả tiền.
        // Lùi bị vướng lịch của người thuê sau thì hoàn tiền những ngày bị mất. Trả về câu giải thích (rỗng nếu không trễ).
        private async Task<string> ApplyLateDeliveryAsync(Rental rental, DateTime now)
        {
            var today = now.AddHours(7).Date; // ngày theo giờ Việt Nam
            int lateDays = (today - rental.StartDate.Date).Days;

            if (lateDays <= 0)
            {
                return "";
            }

            var oldEnd = rental.EndDate.Date;
            var newEnd = oldEnd.AddDays(lateDays);

            bool blocked = await _unitOfWork.Rentals
                .BuildQuery(r =>
                    r.ItemId == rental.ItemId &&
                    r.Id != rental.Id &&
                    (r.Status == RentalStatus.Approved ||
                     r.Status == RentalStatus.WaitingForPickup ||
                     r.Status == RentalStatus.Rented) &&
                    r.StartDate <= newEnd &&
                    r.EndDate > oldEnd)
                .AnyAsync();

            if (!blocked)
            {
                rental.StartDate = today;
                rental.EndDate = newEnd;
                rental.ShiftedDays = lateDays;

                return $" Đồ đến tay trễ {lateDays} ngày nên hạn trả lùi sang {newEnd:dd/MM/yyyy}.";
            }

            int totalDays = (oldEnd - rental.StartDate.Date).Days + 1;
            int lostDays = Math.Min(lateDays, totalDays);
            // Hoàn theo giá ngày sau ưu đãi (đơn có giảm giá thì mỗi ngày rẻ hơn giá niêm yết)
            decimal dayPrice = rental.PricePerDay * (100 - rental.DiscountPercent) / 100m;
            decimal refund = Math.Min(rental.TotalPrice, Math.Round(lostDays * dayPrice, 0));

            rental.TotalPrice -= refund;
            rental.LateDeliveryRefund = refund;

            if (refund > 0)
            {
                await AddWalletEntryAsync(rental.RenterId, refund, WalletTransactionType.Refund, rental.Id,
                    $"Hoàn {lostDays} ngày thuê đơn #{rental.Id} do nhận đồ trễ");
            }

            return $" Đồ đến tay trễ {lateDays} ngày, không lùi được hạn trả vì đã có lịch thuê sau, " +
                $"nên hoàn {NotificationService.Money(refund)} tiền thuê vào ví người thuê.";
        }

        private static string Cut(string text, int max) => text.Length > max ? text[..max] : text;

        // =========================
        // ĐỒ NGỪNG CHO THUÊ: đóng các đơn chưa giao
        // =========================
        public async Task<int> CloseOpenRentalsAsync(int itemId, string itemName, string reason)
        {
            var ids = await _unitOfWork.Rentals
                .BuildQuery(r =>
                    r.ItemId == itemId &&
                    (r.Status == RentalStatus.Pending ||
                     r.Status == RentalStatus.Approved ||
                     r.Status == RentalStatus.WaitingForPickup))
                .Select(r => r.Id)
                .ToListAsync();

            if (ids.Count == 0)
            {
                return 0;
            }

            var rentals = await _unitOfWork.Rentals.GetByIdsAsync(ids);

            foreach (var rental in rentals)
            {
                bool wasPaid = rental.Status == RentalStatus.WaitingForPickup;
                decimal paidAmount = rental.TotalPrice + rental.DepositAmount;

                if (wasPaid)
                {
                    await AddWalletEntryAsync(
                        rental.RenterId,
                        paidAmount,
                        WalletTransactionType.Refund,
                        rental.Id,
                        $"Hoàn tiền đơn #{rental.Id}: đồ ngừng cho thuê");
                }

                rental.Status = rental.Status == RentalStatus.Pending
                    ? RentalStatus.Rejected
                    : RentalStatus.Cancelled;

                await _notificationService.AddAsync(rental.RenterId, NotificationType.System,
                    "Đơn thuê đã bị hủy",
                    $"Đơn #{rental.Id} '{itemName}' đã bị hủy vì {reason}." +
                    (wasPaid ? $" Đã hoàn {NotificationService.Money(paidAmount)} vào ví." : ""));
            }

            return rentals.Count;
        }

        // Thao tác đụng tới tiền hoặc lịch thuê (duyệt, trả tiền, hủy, hoàn tất) chạy trong transaction Serializable.
        // Hai lệnh gửi cùng lúc (bấm 2 lần, 2 máy) thì SQL Server chặn một lệnh lại, không trừ/cộng tiền 2 lần.
        private async Task<bool> RunSeriallyAsync(Func<Task<bool>> action)
        {
            await _unitOfWork.BeginTransactionAsync(IsolationLevel.Serializable);

            try
            {
                var result = await action();
                await _unitOfWork.CommitTransactionAsync();
                return result;
            }
            catch (DbUpdateException)
            {
                await _unitOfWork.RollbackTransactionAsync();
                throw new InvalidOperationException(
                    "Đơn thuê hoặc ví đang có thao tác khác cùng lúc. Vui lòng tải lại và thử lại.");
            }
            catch
            {
                await _unitOfWork.RollbackTransactionAsync();
                throw;
            }
        }

        // =========================
        // TRANG QUẢN TRỊ
        // =========================
        public async Task<RentalListViewModel> SearchAsync(string? searchTerm, RentalStatus? status, int page = 1)
        {
            var query = _unitOfWork.Rentals.BuildQuery(r => true);

            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                string keyword = searchTerm.Trim();
                int.TryParse(keyword.TrimStart('#'), out int rentalId);

                query = query.Where(r =>
                    r.Id == rentalId ||
                    r.Item.ItemName.Contains(keyword) ||
                    r.Renter.FullName.Contains(keyword) ||
                    r.Item.Owner.FullName.Contains(keyword));
            }

            if (status.HasValue)
                query = query.Where(r => r.Status == status.Value);

            int totalCount = await query.CountAsync();
            const int pageSize = 10;
            page = Math.Clamp(page, 1, Math.Max(1, (totalCount + pageSize - 1) / pageSize));

            var rentals = await query
                .OrderByDescending(r => r.RequestedAt)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(r => new RentalListItemViewModel
                {
                    Id = r.Id,
                    ItemName = r.Item.ItemName,
                    RenterName = r.Renter.FullName,
                    OwnerName = r.Item.Owner.FullName,
                    StartDate = r.StartDate,
                    EndDate = r.EndDate,
                    TotalPrice = r.TotalPrice,
                    Status = r.Status,
                    RequestedAt = r.RequestedAt
                })
                .ToListAsync();

            return new RentalListViewModel
            {
                SearchTerm = searchTerm,
                Status = status,
                Rentals = rentals,
                Page = page, PageSize = pageSize, TotalCount = totalCount
            };
        }

        public async Task<RentalDetailsViewModel?> GetDetailsAsync(int id)
        {
            return await _unitOfWork.Rentals
                .BuildQuery(r => r.Id == id)
                .Select(r => new RentalDetailsViewModel
                {
                    Id = r.Id,
                    ItemName = r.Item.ItemName,
                    CategoryName = r.Item.Category.CategoryName,

                    RenterName = r.Renter.FullName,
                    RenterEmail = r.Renter.Email,
                    RenterPhone = r.Renter.PhoneNumber,

                    OwnerName = r.Item.Owner.FullName,
                    OwnerEmail = r.Item.Owner.Email,
                    OwnerPhone = r.Item.Owner.PhoneNumber,

                    StartDate = r.StartDate,
                    EndDate = r.EndDate,
                    PricePerDay = r.PricePerDay,
                    DepositAmount = r.DepositAmount,
                    TotalPrice = r.TotalPrice,
                    RequestNote = r.RequestNote,
                    Status = r.Status,

                    RequestedAt = r.RequestedAt,
                    ApprovedAt = r.ApprovedAt,
                    ReceivedAt = r.ReceivedAt,
                    ReturnedAt = r.ReturnedAt,
                    CompletedAt = r.CompletedAt,

                    DamageAmount = r.DamageAmount,
                    DamageNote = r.DamageNote,
                    DamageClaimedAt = r.DamageClaimedAt,
                    DisputeReason = r.DisputeReason,
                    DisputedAt = r.DisputedAt,
                    ResolutionNote = r.ResolutionNote,
                    CancelReason = r.CancelReason,
                    DeliveryMethod = r.DeliveryMethod,
                    ShipToText = r.DeliveryMethod == DeliveryMethod.Ghn
                        ? r.ShipToName + " · " + r.ShipToPhone + " · " + r.ShipToAddress + ", " + r.ShipToAreaText
                        : null,
                    ShippingOrderCode = r.ShippingOrderCode,
                    ShippingFee = r.ShippingFee,
                    ShiftedDays = r.ShiftedDays,
                    LateDeliveryRefund = r.LateDeliveryRefund,
                    DiscountPercent = r.DiscountPercent,
                    DiscountAmount = r.DiscountAmount,

                    Payments = r.Payments
                        .OrderBy(p => p.CreatedAt)
                        .Select(p => new PaymentViewModel
                        {
                            Id = p.Id,
                            RentalId = p.RentalId,
                            Amount = p.Amount,
                            PaymentType = p.PaymentType,
                            PaymentMethod = p.PaymentMethod,
                            Status = p.Status,
                            TransactionCode = p.TransactionCode,
                            PaidAt = p.PaidAt,
                            CreatedAt = p.CreatedAt
                        })
                        .ToList(),

                    ConditionReports = r.ConditionReports
                        .OrderBy(c => c.CreatedAt)
                        .Select(c => new ConditionReportViewModel
                        {
                            Id = c.Id,
                            ReportType = c.ReportType,
                            Condition = c.Condition,
                            Description = c.Description,
                            CreatedByName = c.CreatedByUser.FullName,
                            CreatedAt = c.CreatedAt,
                            ImageUrls = c.Images.Select(i => i.ImageUrl).ToList(),
                            AiSummary = c.AiSummary,
                            AiDamages = c.AiDamages,
                            AiSuggestedCondition = c.AiSuggestedCondition,
                            AiNewDamageFound = c.AiNewDamageFound,
                            AiSameItem = c.AiSameItem,
                            AiSuggestedDeduction = c.AiSuggestedDeduction
                        })
                        .ToList()
                })
                .FirstOrDefaultAsync();
        }

        // =========================
        // COMMON QUERY
        // =========================
        private IQueryable<Rental> RentalQuery()
        {
            return _unitOfWork.Rentals
                .BuildQuery(r => true)

                .Include(r => r.Item)
                    .ThenInclude(i => i.Owner)

                .Include(r => r.Item)
                    .ThenInclude(i => i.Images)

                .Include(r => r.Item)
                    .ThenInclude(i => i.Category)

                .Include(r => r.Renter);
        }

        // Lấy rental (có tracking) kèm Item để kiểm tra chủ đồ và cập nhật trạng thái
        private static bool IsRentable(ItemStatus status) =>
            status == ItemStatus.Available || status == ItemStatus.Rented;

        private async Task<Rental?> GetRentalWithItemAsync(int rentalId)
        {
            var rental = await _unitOfWork.Rentals.GetByIdAsync(rentalId);

            if (rental == null)
            {
                return null;
            }

            // EF tự gắn rental.Item khi Item được load vào cùng DbContext
            await _unitOfWork.Items.GetByIdAsync(rental.ItemId);

            return rental;
        }

        // =========================
        // GET DTO INTERNAL
        // =========================
        private async Task<RentalDto?> GetRentalDtoAsync(
            int rentalId)
        {
            var rental = await RentalQuery()
                .FirstOrDefaultAsync(r =>
                    r.Id == rentalId);

            if (rental == null)
            {
                return null;
            }

            return ToDto(rental, await _settingService.GetAsync());
        }

        // Dòng sổ ví, ghi nhận ngay (Completed). Chưa lưu: hàm gọi tự SaveChanges.
        private async Task AddWalletEntryAsync(
            string userId,
            decimal amount,
            WalletTransactionType type,
            int rentalId,
            string note)
        {
            await _unitOfWork.WalletTransactions.AddAsync(new WalletTransaction
            {
                UserId = userId,
                Amount = amount,
                Type = type,
                Status = WalletTransactionStatus.Completed,
                RentalId = rentalId,
                Note = note,
                ProcessedAt = DateTime.UtcNow
            });
        }

        // Ghi vào bảng Payment để trang Admin (chi tiết đơn) thấy lịch sử thanh toán
        private async Task AddPaymentAsync(
            int rentalId,
            decimal amount,
            PaymentType type)
        {
            await _unitOfWork.Payments.AddAsync(new Payment
            {
                RentalId = rentalId,
                Amount = amount,
                PaymentType = type,
                PaymentMethod = PaymentMethod.Wallet,
                Status = PaymentStatus.Paid,
                PaidAt = DateTime.UtcNow
            });
        }

        // =========================
        // ENTITY -> DTO
        // =========================
        private static RentalDto ToDto(
            Rental rental,
            RentMateSettings settings)
        {
            return new RentalDto
            {
                RentalId = rental.Id,

                ItemId = rental.ItemId,
                ItemName = rental.Item.ItemName,
                ItemImageUrl = rental.Item.Images
                    .OrderByDescending(img => img.IsPrimary).ThenBy(img => img.Id)
                    .Select(img => img.ImageUrl)
                    .FirstOrDefault(),
                CategoryName = rental.Item.Category?.CategoryName ?? string.Empty,

                RenterId = rental.RenterId,
                RenterName = rental.Renter.FullName,

                OwnerId = rental.Item.OwnerId,
                OwnerName = rental.Item.Owner.FullName,

                StartDate = rental.StartDate,
                EndDate = rental.EndDate,

                PricePerDay = rental.PricePerDay,
                DepositAmount = rental.DepositAmount,
                TotalPrice = rental.TotalPrice,

                Status = rental.Status.ToString(),

                RequestNote = rental.RequestNote,
                RequestedAt = rental.RequestedAt,
                ApprovedAt = rental.ApprovedAt,
                ReceivedAt = rental.ReceivedAt,
                ReturnedAt = rental.ReturnedAt,
                CompletedAt = rental.CompletedAt,

                DamageAmount = rental.DamageAmount,
                DamageNote = rental.DamageNote,
                DamageClaimedAt = rental.DamageClaimedAt,
                DisputeReason = rental.DisputeReason,
                ResolutionNote = rental.ResolutionNote,
                CancelReason = rental.CancelReason,

                DeliveryMethod = rental.DeliveryMethod.ToString(),
                ShipToName = rental.ShipToName,
                ShipToPhone = rental.ShipToPhone,
                ShipToAddress = rental.ShipToAddress,
                ShipToAreaText = rental.ShipToAreaText,
                ShippingOrderCode = rental.ShippingOrderCode,
                ShippingFee = rental.ShippingFee,
                ExpectedDeliveryAt = rental.ExpectedDeliveryAt,
                ShiftedDays = rental.ShiftedDays,
                LateDeliveryRefund = rental.LateDeliveryRefund,
                DiscountPercent = rental.DiscountPercent,
                DiscountAmount = rental.DiscountAmount,

                PlatformFeePercent = rental.PlatformFeeRate * 100,

                OwnerInspectionDeadline = rental.Status == RentalStatus.Returned
                    ? rental.ReturnedAt?.AddDays(settings.OwnerInspectionDays)
                    : null,
                RenterResponseDeadline = rental.Status == RentalStatus.DamageClaimed
                    ? rental.DamageClaimedAt?.AddDays(settings.RenterResponseDays)
                    : null
            };
        }
    }
}
