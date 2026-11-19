using System.Data;
using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Rentals;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class RentalService : IRentalService
    {
        // Phí nền tảng trừ trên tiền thuê lúc hoàn tất (không tính trên tiền cọc)
        public const decimal PlatformFeeRate = 0.05m;

        // Phần chủ đồ nhận và phần RentMate giữ lại của một đơn (Dashboard dùng để tính doanh thu)
        public static decimal OwnerIncome(decimal totalPrice) => Math.Round(totalPrice * (1 - PlatformFeeRate), 0);

        public static decimal PlatformFee(decimal totalPrice) => totalPrice - OwnerIncome(totalPrice);

        // Đơn đã duyệt mà người thuê chưa thanh toán sau ngần này thì chủ đồ được hủy
        private static readonly TimeSpan PaymentTimeout = TimeSpan.FromHours(24);

        // Giới hạn một đơn thuê: tối đa 30 ngày, đặt trước tối đa 90 ngày
        public const int MaxRentalDays = 30;
        public const int MaxDaysAhead = 90;

        private readonly IUnitOfWork _unitOfWork;
        private readonly IWalletService _walletService;
        private readonly INotificationService _notificationService;
        private readonly IAuditLogService _auditLogService;

        // Sau khi người thuê trả đồ: chủ đồ có 3 ngày kiểm tra; người thuê có 2 ngày phản hồi yêu cầu bồi thường
        public const int OwnerInspectionDays = 3;
        public const int RenterResponseDays = 2;

        public RentalService(IUnitOfWork unitOfWork, IWalletService walletService, INotificationService notificationService, IAuditLogService auditLogService)
        {
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

            if (dto.StartDate.Date > DateTime.UtcNow.Date.AddDays(MaxDaysAhead))
            {
                throw new ArgumentException(
                    $"Chỉ đặt thuê trước tối đa {MaxDaysAhead} ngày.");
            }

            var numberOfDays =
                (dto.EndDate.Date - dto.StartDate.Date).Days + 1;

            if (numberOfDays > MaxRentalDays)
            {
                throw new ArgumentException(
                    $"Mỗi đơn thuê tối đa {MaxRentalDays} ngày.");
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

            var rental = new Rental
            {
                ItemId = item.Id,
                RenterId = renterId,

                StartDate = dto.StartDate.Date,
                EndDate = dto.EndDate.Date,

                // Giữ giá tại thời điểm tạo đơn
                PricePerDay = item.PricePerDay,
                DepositAmount = item.DepositAmount,

                TotalPrice =
                    item.PricePerDay * numberOfDays,

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

            return rentals
                .Select(ToDto)
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

            return ToDto(rental);
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

            if (rental.Item.Status == ItemStatus.Hidden || rental.Item.Status == ItemStatus.Unavailable)
            {
                throw new InvalidOperationException(
                    "Đồ đang bị ẩn hoặc tạm ngưng, không duyệt được đơn.");
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
        public async Task<bool> PickupAsync(
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

            var hasBeforeReport = await _unitOfWork.ConditionReports
                .BuildQuery(c =>
                    c.RentalId == rentalId &&
                    c.ReportType == ConditionReportType.BeforeRental)
                .AnyAsync();

            if (!hasBeforeReport)
            {
                throw new InvalidOperationException(
                    "Chủ đồ chưa lập biên bản lúc giao (có ảnh), chưa xác nhận nhận đồ được.");
            }

            rental.Status = RentalStatus.Rented;
            rental.ReceivedAt = DateTime.UtcNow;

            rental.Item.Status = ItemStatus.Rented;

            await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.System,
                "Người thuê đã nhận đồ",
                $"Đơn #{rental.Id} '{rental.Item.ItemName}': người thuê đã nhận đồ và đồng ý biên bản lúc giao. Hạn trả {rental.EndDate:dd/MM/yyyy}.");

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

            await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.ReturnReminder,
                "Người thuê đã trả đồ",
                $"Đơn #{rental.Id} '{rental.Item.ItemName}': trong {OwnerInspectionDays} ngày, hãy chụp ảnh lập biên bản nhận lại (AI so sánh với lúc giao) rồi bấm Hoàn tất.");

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

            if (isRenter)
            {
                if (rental.Status != RentalStatus.Returned)
                {
                    throw new InvalidOperationException(
                        "Chỉ tự hoàn tất được khi đã trả đồ mà chủ đồ chưa xử lý.");
                }

                var deadline = (rental.ReturnedAt ?? now).AddDays(OwnerInspectionDays);

                if (now < deadline)
                {
                    throw new InvalidOperationException(
                        $"Chủ đồ có {OwnerInspectionDays} ngày để kiểm tra đồ. Bạn tự hoàn tất được sau {deadline.ToLocalTime():dd/MM HH:mm}.");
                }

                await SettleAsync(rental, 0,
                    $"Chủ đồ không kiểm tra đồ trong {OwnerInspectionDays} ngày nên đơn tự hoàn tất.");

                return true;
            }

            if (rental.Status == RentalStatus.DamageClaimed)
            {
                var deadline = (rental.DamageClaimedAt ?? now).AddDays(RenterResponseDays);

                if (now < deadline)
                {
                    throw new InvalidOperationException(
                        $"Đang chờ người thuê phản hồi yêu cầu bồi thường (đến {deadline.ToLocalTime():dd/MM HH:mm}).");
                }

                await SettleAsync(rental, rental.DamageAmount,
                    $"Người thuê không phản hồi trong {RenterResponseDays} ngày nên áp dụng mức bồi thường chủ đồ đề nghị.");

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

            await _notificationService.AddAsync(rental.RenterId, NotificationType.Payment,
                "Chủ đồ yêu cầu bồi thường",
                $"Đơn #{rental.Id} '{rental.Item.ItemName}': chủ đồ đề nghị trừ {NotificationService.Money(damageAmount)} tiền cọc. " +
                $"Lý do: {rental.DamageNote}. Vào Đơn thuê để đồng ý hoặc khiếu nại trong {RenterResponseDays} ngày.");

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
                    $"Phân xử khiếu nại đơn #{rental.Id}: trừ {damageAmount:N0} đ / cọc {rental.DepositAmount:N0} đ (chủ đồ đề nghị {rental.DamageAmount:N0} đ). Kết luận: {rental.ResolutionNote}",
                    ipAddress, adminId);

                await SettleAsync(rental, damageAmount, $"Quản trị viên đã phân xử: {rental.ResolutionNote}");

                return true;
            });

        private static void ValidateDamage(Rental rental, decimal damageAmount)
        {
            if (damageAmount < 0 || damageAmount > rental.DepositAmount)
            {
                throw new InvalidOperationException(
                    $"Tiền bồi thường từ 0 đến {rental.DepositAmount:N0} đ (không vượt tiền cọc).");
            }
        }

        // Chốt đơn: chủ đồ nhận tiền thuê trừ phí + tiền bồi thường, người thuê nhận lại phần cọc còn lại.
        // Một lần SaveChanges: đổi trạng thái đơn và cộng tiền cùng thành công hoặc cùng thất bại.
        private async Task SettleAsync(Rental rental, decimal damageAmount, string? extraNote)
        {
            rental.Status = RentalStatus.Completed;
            rental.CompletedAt = DateTime.UtcNow;
            rental.DamageAmount = damageAmount;

            rental.Item.Status = ItemStatus.Available;

            var ownerIncome = OwnerIncome(rental.TotalPrice);
            var refund = rental.DepositAmount - damageAmount;

            await AddWalletEntryAsync(
                rental.Item.OwnerId,
                ownerIncome,
                WalletTransactionType.RentalIncome,
                rental.Id,
                $"Tiền thuê đơn #{rental.Id} (đã trừ phí {PlatformFeeRate:P0})");

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
                        ? $"Hoàn cọc đơn #{rental.Id} (đã trừ {damageAmount:N0} đ bồi thường)"
                        : $"Hoàn cọc đơn #{rental.Id}");

                await AddPaymentAsync(rental.Id, refund, PaymentType.DepositRefund);
            }

            string suffix = string.IsNullOrEmpty(extraNote) ? "" : " " + extraNote;

            await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.Payment,
                "Bạn nhận được tiền thuê",
                $"Đơn #{rental.Id} '{rental.Item.ItemName}' đã hoàn tất. {NotificationService.Money(ownerIncome)} tiền thuê (đã trừ phí {PlatformFeeRate:P0})" +
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

            if (rental.Item.Status == ItemStatus.Hidden || rental.Item.Status == ItemStatus.Unavailable)
            {
                throw new InvalidOperationException(
                    "Đồ đang bị ẩn hoặc tạm ngưng, chưa thanh toán được.");
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
        public Task<bool> CancelAsync(int rentalId, string userId) =>
            RunSeriallyAsync(() => CancelCoreAsync(rentalId, userId));

        private async Task<bool> CancelCoreAsync(
            int rentalId,
            string userId)
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
                // Chủ đồ chỉ hủy được đơn đã duyệt mà người thuê không thanh toán sau 24 giờ
                if (rental.Status != RentalStatus.Approved ||
                    rental.ApprovedAt == null ||
                    DateTime.UtcNow - rental.ApprovedAt.Value < PaymentTimeout)
                {
                    throw new InvalidOperationException(
                        "Chủ đồ chỉ hủy được đơn đã duyệt mà người thuê chưa thanh toán sau 24 giờ.");
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

            // Báo cho bên còn lại
            if (isRenter)
            {
                await _notificationService.AddAsync(rental.Item.OwnerId, NotificationType.System,
                    "Đơn thuê đã bị hủy",
                    $"Người thuê đã hủy đơn #{rental.Id} '{rental.Item.ItemName}'.");
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

                .Include(r => r.Renter);
        }

        // Lấy rental (có tracking) kèm Item để kiểm tra chủ đồ và cập nhật trạng thái
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

            return ToDto(rental);
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
            Rental rental)
        {
            return new RentalDto
            {
                RentalId = rental.Id,

                ItemId = rental.ItemId,
                ItemName = rental.Item.ItemName,

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

                OwnerInspectionDeadline = rental.Status == RentalStatus.Returned
                    ? rental.ReturnedAt?.AddDays(OwnerInspectionDays)
                    : null,
                RenterResponseDeadline = rental.Status == RentalStatus.DamageClaimed
                    ? rental.DamageClaimedAt?.AddDays(RenterResponseDays)
                    : null
            };
        }
    }
}
