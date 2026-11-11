using Microsoft.EntityFrameworkCore;
using RentMate.Core.Enums;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Items;
using RentMate.Service.Interfaces;

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

        // =========================
        // GET ALL
        // =========================
        public async Task<List<ItemDto>> GetAllAsync()
        {
            return await _unitOfWork.Items
                .BuildQuery(i => i.Status != ItemStatus.Hidden)
                .Select(i => new ItemDto
                {
                    ItemId = i.Id,
                    ItemName = i.ItemName,
                    Description = i.Description,
                    PricePerDay = i.PricePerDay,
                    DepositAmount = i.DepositAmount,

                    Condition = i.Condition.ToString(),
                    Status = i.Status.ToString(),

                    CategoryId = i.CategoryId,
                    CategoryName = i.Category.CategoryName,

                    OwnerId = i.OwnerId,
                    OwnerName = i.Owner.FullName,

                    CreatedAt = i.CreatedAt
                })
                .ToListAsync();
        }

        // =========================
        // GET BY ID
        // =========================
        public async Task<ItemDto?> GetByIdAsync(int id)
        {
            return await _unitOfWork.Items
                .BuildQuery(i =>
                    i.Id == id &&
                    i.Status != ItemStatus.Hidden)
                .Select(i => new ItemDto
                {
                    ItemId = i.Id,
                    ItemName = i.ItemName,
                    Description = i.Description,
                    PricePerDay = i.PricePerDay,
                    DepositAmount = i.DepositAmount,

                    Condition = i.Condition.ToString(),
                    Status = i.Status.ToString(),

                    CategoryId = i.CategoryId,
                    CategoryName = i.Category.CategoryName,

                    OwnerId = i.OwnerId,
                    OwnerName = i.Owner.FullName,

                    CreatedAt = i.CreatedAt
                })
                .FirstOrDefaultAsync();
        }

        // =========================
        // CREATE
        // =========================
        public async Task<ItemDto> CreateAsync(
            CreateItemDto dto,
            string ownerId)
        {
            await EnsureCategoryAssignableAsync(dto.CategoryId);

            if (!Enum.IsDefined(
                typeof(ItemCondition),
                dto.Condition))
            {
                throw new ArgumentException(
                    "Invalid item condition.");
            }

            if (dto.PricePerDay <= 0)
            {
                throw new ArgumentException(
                    "Price per day must be greater than 0.");
            }

            if (dto.DepositAmount < 0)
            {
                throw new ArgumentException(
                    "Deposit amount cannot be negative.");
            }

            var item = new Item
            {
                ItemName = dto.ItemName.Trim(),
                Description = dto.Description,

                PricePerDay = dto.PricePerDay,
                DepositAmount = dto.DepositAmount,

                CategoryId = dto.CategoryId,

                Condition =
                    (ItemCondition)dto.Condition,

                Status = ItemStatus.Available,

                OwnerId = ownerId,

                CreatedAt = DateTime.UtcNow
            };

            await _unitOfWork.Items.AddAsync(item);

            await _unitOfWork.SaveChangesAsync();

            return (await GetByIdAsync(item.Id))!;
        }

        // =========================
        // UPDATE
        // =========================
        public async Task<bool> UpdateAsync(
            int id,
            UpdateItemDto dto,
            string ownerId)
        {
            var item =
                await _unitOfWork.Items.GetByIdAsync(id);

            if (item == null)
            {
                return false;
            }

            // Chỉ chủ sở hữu mới được sửa
            if (item.OwnerId != ownerId)
            {
                throw new UnauthorizedAccessException(
                    "You are not the owner of this item.");
            }

            await EnsureCategoryAssignableAsync(dto.CategoryId);

            if (!Enum.IsDefined(
                typeof(ItemCondition),
                dto.Condition))
            {
                throw new ArgumentException(
                    "Invalid item condition.");
            }

            if (dto.PricePerDay <= 0)
            {
                throw new ArgumentException(
                    "Price per day must be greater than 0.");
            }

            item.ItemName = dto.ItemName.Trim();
            item.Description = dto.Description;

            item.PricePerDay = dto.PricePerDay;
            item.DepositAmount = dto.DepositAmount;

            item.CategoryId = dto.CategoryId;

            item.Condition =
                (ItemCondition)dto.Condition;

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
            var item =
                await _unitOfWork.Items.GetByIdAsync(id);

            if (item == null)
            {
                return false;
            }

            if (item.OwnerId != ownerId)
            {
                throw new UnauthorizedAccessException(
                    "You are not the owner of this item.");
            }

            // Không xóa cứng vì sau này còn Rental history
            item.Status = ItemStatus.Hidden;

            await _unitOfWork.SaveChangesAsync();

            return true;
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

            var items = await query
                .OrderByDescending(i => i.CreatedAt)
                .Skip((page - 1) * pageSize).Take(pageSize)
                .Select(i => new ItemListItemViewModel
                {
                    Id = i.Id,
                    ItemName = i.ItemName,
                    ImageUrl = i.Images
                        .OrderByDescending(img => img.IsPrimary)
                        .Select(img => img.ImageUrl)
                        .FirstOrDefault(),
                    CategoryName = i.Category.CategoryName,
                    OwnerName = i.Owner.FullName,
                    OwnerEmail = i.Owner.Email,
                    PricePerDay = i.PricePerDay,
                    DepositAmount = i.DepositAmount,
                    Condition = i.Condition,
                    Status = i.Status,
                    RentalCount = i.Rentals.Count,
                    CreatedAt = i.CreatedAt
                })
                .ToListAsync();

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
                Page = page, PageSize = pageSize, TotalCount = totalCount
            };
        }

        public async Task UpdateStatusAsync(int id, ItemStatus status, string actorUserId, string ipAddress)
        {
            if (!Enum.IsDefined(status))
                throw new InvalidOperationException("Trạng thái không hợp lệ.");

            var item = await _unitOfWork.Items.GetByIdAsync(id);

            if (item == null)
                throw new InvalidOperationException("Đồ cho thuê không tồn tại.");

            // Trạng thái "Đang cho thuê" do luồng đơn thuê quyết định
            if (status == ItemStatus.Rented)
                throw new InvalidOperationException("Không thể chuyển thủ công sang trạng thái đang cho thuê.");

            if (item.Status == ItemStatus.Rented)
                throw new InvalidOperationException("Đồ đang được thuê, không thể đổi trạng thái lúc này.");

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
                throw new ArgumentException("Category does not exist.");

            if (category.HasActiveChildren)
                throw new ArgumentException("This category has subcategories. Please choose a subcategory.");
        }
    }
}
