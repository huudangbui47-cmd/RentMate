using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Items;
using RentMate.Service.Interfaces;
using System.Linq.Expressions;

namespace RentMate.Service.Services
{
    public class ItemService : IItemService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuditLogService _auditLogService;

        public ItemService(IUnitOfWork unitOfWork, IAuditLogService auditLogService)
        {
            _unitOfWork = unitOfWork;
            _auditLogService = auditLogService;
        }

        // Đồ khách khác nhìn thấy trên app: đã được duyệt và chưa bị tạm ngưng/ẩn
        private static readonly Expression<Func<Item, bool>> IsPublic =
            i => i.Status == ItemStatus.Available || i.Status == ItemStatus.Rented;

        private static readonly Expression<Func<Item, ItemDto>> ToDto = i => new ItemDto
        {
            ItemId = i.Id,
            ItemName = i.ItemName,
            Description = i.Description,
            PricePerDay = i.PricePerDay,
            DepositAmount = i.DepositAmount,

            Condition = i.Condition.ToString(),
            Status = i.Status.ToString(),
            RejectionReason = i.RejectionReason,

            CategoryId = i.CategoryId,
            CategoryName = i.Category.CategoryName,

            OwnerId = i.OwnerId,
            OwnerName = i.Owner.FullName,
            OwnerAvatarUrl = i.Owner.AvatarUrl,

            CreatedAt = i.CreatedAt,

            ImageUrl = i.Images
                .OrderByDescending(img => img.IsPrimary).ThenBy(img => img.Id)
                .Select(img => img.ImageUrl)
                .FirstOrDefault(),

            Images = i.Images
                .OrderByDescending(img => img.IsPrimary).ThenBy(img => img.Id)
                .Select(img => new ItemImageDto
                {
                    ImageId = img.Id,
                    ImageUrl = img.ImageUrl,
                    IsPrimary = img.IsPrimary
                })
                .ToList()
        };

        public const int MaxImagesPerItem = 8;

        // =========================
        // GET ALL (trang chủ app)
        // =========================
        public async Task<List<ItemDto>> GetAllAsync()
        {
            return await _unitOfWork.Items
                .BuildQuery(IsPublic)
                .OrderByDescending(i => i.CreatedAt)
                .Select(ToDto)
                .ToListAsync();
        }

        // =========================
        // GET BY ID
        // =========================
        // Khách khác chỉ xem được đồ đã duyệt; chủ đồ xem được đồ của mình ở mọi trạng thái (trừ đã xóa)
        public async Task<ItemDto?> GetByIdAsync(int id, string? viewerId = null)
        {
            return await _unitOfWork.Items
                .BuildQuery(i => i.Id == id && i.Status != ItemStatus.Hidden)
                .Where(i => i.Status == ItemStatus.Available || i.Status == ItemStatus.Rented || i.OwnerId == viewerId)
                .Select(ToDto)
                .FirstOrDefaultAsync();
        }

        // =========================
        // ĐỒ CỦA TÔI
        // =========================
        public async Task<List<ItemDto>> GetMyItemsAsync(string ownerId)
        {
            return await _unitOfWork.Items
                .BuildQuery(i => i.OwnerId == ownerId && i.Status != ItemStatus.Hidden)
                .OrderByDescending(i => i.CreatedAt)
                .Select(ToDto)
                .ToListAsync();
        }

        // =========================
        // CREATE
        // =========================
        public async Task<ItemDto> CreateAsync(
            CreateItemDto dto,
            string ownerId)
        {
            await ValidateAsync(dto.ItemName, dto.PricePerDay, dto.DepositAmount, dto.CategoryId, dto.Condition);

            var item = new Item
            {
                ItemName = dto.ItemName.Trim(),
                Description = dto.Description?.Trim(),

                PricePerDay = dto.PricePerDay,
                DepositAmount = dto.DepositAmount,

                CategoryId = dto.CategoryId,

                Condition = (ItemCondition)dto.Condition,

                // Đồ mới phải chờ quản lý duyệt mới hiện trên app
                Status = ItemStatus.PendingApproval,

                OwnerId = ownerId,

                CreatedAt = DateTime.UtcNow
            };

            await _unitOfWork.Items.AddAsync(item);

            await _unitOfWork.SaveChangesAsync();

            return (await GetByIdAsync(item.Id, ownerId))!;
        }

        // =========================
        // UPDATE
        // =========================
        public async Task<bool> UpdateAsync(
            int id,
            UpdateItemDto dto,
            string ownerId)
        {
            // Chỉ chủ sở hữu mới được sửa, đồ đang được thuê thì chưa sửa được
            var item = await GetOwnedEditableItemAsync(id, ownerId);

            if (item == null)
            {
                return false;
            }

            await ValidateAsync(dto.ItemName, dto.PricePerDay, dto.DepositAmount, dto.CategoryId, dto.Condition);

            item.ItemName = dto.ItemName.Trim();
            item.Description = dto.Description?.Trim();

            item.PricePerDay = dto.PricePerDay;
            item.DepositAmount = dto.DepositAmount;

            item.CategoryId = dto.CategoryId;

            item.Condition = (ItemCondition)dto.Condition;

            MarkForReapproval(item);

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // DELETE / HIDE
        // =========================
        public async Task<bool> DeleteAsync(
            int id,
            string ownerId)
        {
            var item = await _unitOfWork.Items.GetByIdAsync(id);

            if (item == null || item.Status == ItemStatus.Hidden)
            {
                return false;
            }

            if (item.OwnerId != ownerId)
            {
                throw new UnauthorizedAccessException();
            }

            if (item.Status == ItemStatus.Rented)
            {
                throw new ArgumentException("Đồ đang được thuê, không xóa được.");
            }

            // Không xóa cứng vì còn lịch sử đơn thuê
            item.Status = ItemStatus.Hidden;

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // =========================
        // ẢNH ĐỒ CHO THUÊ
        // =========================
        // Controller đã lưu file, ở đây chỉ ghi đường dẫn vào DB. Trả về null nếu không có đồ.
        public async Task<List<ItemImageDto>?> AddImagesAsync(int itemId, List<string> imageUrls, string ownerId)
        {
            var item = await GetOwnedEditableItemAsync(itemId, ownerId);

            if (item == null)
                return null;

            var current = await _unitOfWork.ItemImages
                .BuildQuery(img => img.ItemId == itemId)
                .Select(img => img.IsPrimary)
                .ToListAsync();

            if (current.Count + imageUrls.Count > MaxImagesPerItem)
                throw new ArgumentException($"Mỗi món đồ tối đa {MaxImagesPerItem} ảnh (hiện đã có {current.Count} ảnh).");

            bool hasPrimary = current.Any(isPrimary => isPrimary);

            foreach (string url in imageUrls)
            {
                await _unitOfWork.ItemImages.AddAsync(new ItemImage
                {
                    ItemId = itemId,
                    ImageUrl = url,
                    // Món đồ chưa có ảnh thì ảnh đầu tiên làm ảnh chính
                    IsPrimary = !hasPrimary,
                    CreatedAt = DateTime.UtcNow
                });

                hasPrimary = true;
            }

            // Ảnh mới cũng là nội dung mới nên phải duyệt lại (giống khi sửa thông tin)
            MarkForReapproval(item);

            await _unitOfWork.SaveChangesAsync();

            return (await GetByIdAsync(itemId, ownerId))!.Images;
        }

        // Trả về đường dẫn ảnh đã xóa để controller xóa file. Null nếu không có đồ/ảnh.
        public async Task<string?> DeleteImageAsync(int itemId, int imageId, string ownerId)
        {
            var item = await GetOwnedEditableItemAsync(itemId, ownerId);

            if (item == null)
                return null;

            var images = await _unitOfWork.ItemImages
                .BuildQuery(img => img.ItemId == itemId)
                .OrderBy(img => img.Id)
                .ToListAsync();

            var image = images.FirstOrDefault(img => img.Id == imageId);

            if (image == null)
                return null;

            _unitOfWork.ItemImages.Delete(image);

            // Xóa ảnh chính thì ảnh tải lên sớm nhất còn lại thành ảnh chính
            if (image.IsPrimary)
            {
                var next = images.FirstOrDefault(img => img.Id != imageId);

                if (next != null)
                    next.IsPrimary = true;
            }

            await _unitOfWork.SaveChangesAsync();

            return image.ImageUrl;
        }

        public async Task<bool> SetPrimaryImageAsync(int itemId, int imageId, string ownerId)
        {
            var item = await GetOwnedEditableItemAsync(itemId, ownerId);

            if (item == null)
                return false;

            var images = await _unitOfWork.ItemImages
                .BuildQuery(img => img.ItemId == itemId)
                .ToListAsync();

            if (!images.Any(img => img.Id == imageId))
                return false;

            foreach (var img in images)
                img.IsPrimary = img.Id == imageId;

            await _unitOfWork.SaveChangesAsync();

            return true;
        }

        // Null nếu đồ không tồn tại/đã xóa. Không phải chủ đồ hoặc đồ đang được thuê thì báo lỗi.
        private async Task<Item?> GetOwnedEditableItemAsync(int itemId, string ownerId)
        {
            var item = await _unitOfWork.Items.GetByIdAsync(itemId);

            if (item == null || item.Status == ItemStatus.Hidden)
                return null;

            if (item.OwnerId != ownerId)
                throw new UnauthorizedAccessException();

            if (item.Status == ItemStatus.Rented)
                throw new ArgumentException("Đồ đang được thuê, bạn sửa lại sau khi đơn thuê kết thúc.");

            return item;
        }

        // Nội dung đã đổi nên phải duyệt lại. Đồ bị quản lý tạm ngưng thì vẫn giữ tạm ngưng.
        private static void MarkForReapproval(Item item)
        {
            if (item.Status != ItemStatus.Unavailable)
            {
                item.Status = ItemStatus.PendingApproval;
                item.RejectionReason = null;
            }
        }

        // =========================
        // TRANG QUẢN TRỊ
        // =========================
        public async Task<ItemListViewModel> SearchAsync(string? searchTerm, int? categoryId, ItemStatus? status, int page = 1)
        {
            var query = _unitOfWork.Items.BuildQuery(i => true);

            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                string keyword = searchTerm.Trim();

                query = query.Where(i =>
                    i.ItemName.Contains(keyword) ||
                    i.Owner.FullName.Contains(keyword) ||
                    (i.Owner.Email != null && i.Owner.Email.Contains(keyword)));
            }

            // Lọc theo danh mục cha thì lấy cả đồ trong các danh mục con
            if (categoryId.HasValue)
                query = query.Where(i => i.CategoryId == categoryId.Value || i.Category.ParentCategoryId == categoryId.Value);

            if (status.HasValue)
                query = query.Where(i => i.Status == status.Value);

            int totalCount = await query.CountAsync();
            const int pageSize = 10;
            page = Math.Clamp(page, 1, Math.Max(1, (totalCount + pageSize - 1) / pageSize));

            // Đang xem danh sách chờ duyệt thì đồ đăng trước được duyệt trước
            var ordered = status == ItemStatus.PendingApproval
                ? query.OrderBy(i => i.CreatedAt)
                : query.OrderByDescending(i => i.CreatedAt);

            var items = await ordered
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(i => new ItemListItemViewModel
                {
                    Id = i.Id,
                    ItemName = i.ItemName,
                    Description = i.Description,
                    ImageUrl = i.Images
                        .OrderByDescending(img => img.IsPrimary).ThenBy(img => img.Id)
                        .Select(img => img.ImageUrl)
                        .FirstOrDefault(),
                    ImageUrls = i.Images
                        .OrderByDescending(img => img.IsPrimary).ThenBy(img => img.Id)
                        .Select(img => img.ImageUrl)
                        .ToList(),
                    CategoryName = i.Category.CategoryName,
                    OwnerName = i.Owner.FullName,
                    OwnerEmail = i.Owner.Email,
                    PricePerDay = i.PricePerDay,
                    DepositAmount = i.DepositAmount,
                    Condition = i.Condition,
                    Status = i.Status,
                    RejectionReason = i.RejectionReason,
                    RentalCount = i.Rentals.Count,
                    CreatedAt = i.CreatedAt
                })
                .ToListAsync();

            int pendingCount = await _unitOfWork.Items
                .BuildQuery(i => i.Status == ItemStatus.PendingApproval)
                .CountAsync();

            var allCategories = await _unitOfWork.Categories
                .BuildQuery(c => true)
                .Select(c => new CategoryOptionViewModel
                {
                    Id = c.Id,
                    CategoryName = c.CategoryName,
                    ParentCategoryId = c.ParentCategoryId
                })
                .ToListAsync();

            // Mỗi danh mục cha đứng trước các danh mục con của nó
            var categories = new List<CategoryOptionViewModel>();

            foreach (var parent in allCategories.Where(c => c.ParentCategoryId == null).OrderBy(c => c.CategoryName))
            {
                categories.Add(parent);
                categories.AddRange(allCategories.Where(c => c.ParentCategoryId == parent.Id).OrderBy(c => c.CategoryName));
            }

            return new ItemListViewModel
            {
                SearchTerm = searchTerm,
                CategoryId = categoryId,
                Status = status,
                Items = items,
                Categories = categories,
                PendingCount = pendingCount,
                Page = page, PageSize = pageSize, TotalCount = totalCount
            };
        }

        public async Task UpdateStatusAsync(int id, ItemStatus status, string actorUserId, string ipAddress)
        {
            // Duyệt/từ chối có nút riêng; "Đang cho thuê" do luồng đơn thuê quyết định
            if (status != ItemStatus.Available && status != ItemStatus.Unavailable && status != ItemStatus.Hidden)
                throw new InvalidOperationException("Trạng thái không hợp lệ.");

            var item = await _unitOfWork.Items.GetByIdAsync(id)
                ?? throw new InvalidOperationException("Đồ cho thuê không tồn tại.");

            if (item.Status == ItemStatus.Rented)
                throw new InvalidOperationException("Đồ đang được thuê, không thể đổi trạng thái lúc này.");

            if ((item.Status == ItemStatus.PendingApproval || item.Status == ItemStatus.Rejected) && status != ItemStatus.Hidden)
                throw new InvalidOperationException("Đồ này chưa được duyệt. Hãy dùng nút Duyệt hoặc Từ chối.");

            if (item.Status == status)
                throw new InvalidOperationException("Đồ đã ở trạng thái này rồi.");

            var oldStatus = item.Status;

            item.Status = status;

            await _auditLogService.RecordAsync(
                "UpdateItemStatus",
                "Item",
                item.Id.ToString(),
                $"Đổi trạng thái '{item.ItemName}': {oldStatus} → {status}",
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task ApproveAsync(int id, string actorUserId, string ipAddress)
        {
            var item = await GetPendingItemAsync(id);

            item.Status = ItemStatus.Available;
            item.RejectionReason = null;

            await _auditLogService.RecordAsync("ApproveItem", "Item", item.Id.ToString(),
                $"Duyệt đồ '{item.ItemName}'.", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task RejectAsync(int id, string reason, string actorUserId, string ipAddress)
        {
            reason = reason?.Trim() ?? string.Empty;

            if (reason.Length == 0)
                throw new InvalidOperationException("Vui lòng nhập lý do từ chối để chủ đồ biết cần sửa gì.");

            if (reason.Length > 500)
                throw new InvalidOperationException("Lý do từ chối tối đa 500 ký tự.");

            var item = await GetPendingItemAsync(id);

            item.Status = ItemStatus.Rejected;
            item.RejectionReason = reason;

            await _auditLogService.RecordAsync("RejectItem", "Item", item.Id.ToString(),
                $"Từ chối đồ '{item.ItemName}'. Lý do: {reason}", ipAddress, actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        private async Task<Item> GetPendingItemAsync(int id)
        {
            var item = await _unitOfWork.Items.GetByIdAsync(id)
                ?? throw new InvalidOperationException("Đồ cho thuê không tồn tại.");

            // Hai quản lý cùng xử lý: người sau thấy thông báo thay vì làm lại
            if (item.Status != ItemStatus.PendingApproval)
                throw new InvalidOperationException("Đồ này đã được xử lý hoặc chủ đồ đã thay đổi. Vui lòng tải lại trang.");

            return item;
        }

        private async Task ValidateAsync(string itemName, decimal pricePerDay, decimal depositAmount, int categoryId, int condition)
        {
            if (string.IsNullOrWhiteSpace(itemName))
                throw new ArgumentException("Vui lòng nhập tên đồ.");

            if (itemName.Trim().Length > 200)
                throw new ArgumentException("Tên đồ tối đa 200 ký tự.");

            if (!Enum.IsDefined(typeof(ItemCondition), condition))
                throw new ArgumentException("Tình trạng đồ không hợp lệ.");

            if (pricePerDay <= 0)
                throw new ArgumentException("Giá thuê mỗi ngày phải lớn hơn 0.");

            if (depositAmount < 0)
                throw new ArgumentException("Tiền cọc không được âm.");

            await EnsureCategoryAssignableAsync(categoryId);
        }

        // Đồ chỉ được gắn vào danh mục đang hoạt động (và danh mục cha cũng đang hoạt động).
        // Danh mục cha đã có danh mục con thì phải chọn danh mục con.
        private async Task EnsureCategoryAssignableAsync(int categoryId)
        {
            var category = await _unitOfWork.Categories
                .BuildQuery(c => c.Id == categoryId)
                .Select(c => new
                {
                    c.IsActive,
                    ParentActive = c.ParentCategory == null || c.ParentCategory.IsActive,
                    HasActiveChildren = c.Children.Any(child => child.IsActive)
                })
                .FirstOrDefaultAsync();

            if (category == null || !category.IsActive || !category.ParentActive)
                throw new ArgumentException("Danh mục không tồn tại hoặc đã ngừng hoạt động.");

            if (category.HasActiveChildren)
                throw new ArgumentException("Danh mục này có danh mục con, vui lòng chọn một danh mục con.");
        }
    }
}
