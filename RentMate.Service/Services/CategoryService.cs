using Microsoft.EntityFrameworkCore;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Core.ViewModels;
using RentMate.Service.DTOs.Categories;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class CategoryService : ICategoryService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuditLogService _auditLogService;

        public CategoryService(IUnitOfWork unitOfWork, IAuditLogService auditLogService)
        {
            _unitOfWork = unitOfWork;
            _auditLogService = auditLogService;
        }

        // =========================
        // API
        // =========================

        // Chỉ trả danh mục đang hoạt động; danh mục con bị ẩn theo khi danh mục cha ngừng hoạt động
        public async Task<List<CategoryDto>> GetAllAsync()
        {
            var categories = await _unitOfWork.Categories
                .BuildQuery(c => c.IsActive && (c.ParentCategory == null || c.ParentCategory.IsActive))
                .OrderBy(c => c.CategoryName)
                .Select(c => new CategoryDto
                {
                    CategoryId = c.Id,
                    CategoryName = c.CategoryName,
                    Description = c.Description,
                    IsActive = c.IsActive,
                    ParentCategoryId = c.ParentCategoryId
                })
                .ToListAsync();

            // Mỗi danh mục cha đứng ngay trước các danh mục con của nó (app hiển thị theo đúng thứ tự này)
            var ordered = new List<CategoryDto>();

            foreach (var parent in categories.Where(c => c.ParentCategoryId == null))
            {
                ordered.Add(parent);
                ordered.AddRange(categories.Where(c => c.ParentCategoryId == parent.CategoryId));
            }

            return ordered;
        }

        public async Task<CategoryDto?> GetByIdAsync(int id)
        {
            return await _unitOfWork.Categories
                .BuildQuery(c => c.Id == id)
                .Select(c => new CategoryDto
                {
                    CategoryId = c.Id,
                    CategoryName = c.CategoryName,
                    Description = c.Description,
                    IsActive = c.IsActive,
                    ParentCategoryId = c.ParentCategoryId
                })
                .FirstOrDefaultAsync();
        }

        // =========================
        // TRANG QUẢN TRỊ
        // =========================

        // Sắp xếp sẵn: mỗi danh mục cha đứng trước các danh mục con của nó
        public async Task<List<CategoryViewModel>> GetAllForManagementAsync()
        {
            var categories = await _unitOfWork.Categories
                .BuildQuery(c => true)
                .Select(c => new CategoryViewModel
                {
                    Id = c.Id,
                    RowVersion = Convert.ToBase64String(c.RowVersion),
                    CategoryName = c.CategoryName,
                    Description = c.Description,
                    IsActive = c.IsActive,
                    ParentCategoryId = c.ParentCategoryId,
                    ParentCategoryName = c.ParentCategory != null ? c.ParentCategory.CategoryName : null,
                    ChildCount = c.Children.Count,
                    ItemCount = c.Items.Count + c.Children.SelectMany(child => child.Items).Count()
                })
                .ToListAsync();

            var result = new List<CategoryViewModel>();

            foreach (var parent in categories.Where(c => c.ParentCategoryId == null).OrderBy(c => c.CategoryName))
            {
                result.Add(parent);
                result.AddRange(categories.Where(c => c.ParentCategoryId == parent.Id).OrderBy(c => c.CategoryName));
            }

            return result;
        }

        // Danh sách để chọn "Thuộc danh mục": chỉ danh mục cha vì hệ thống chỉ có 2 cấp
        public async Task<List<CategoryOptionViewModel>> GetParentOptionsAsync()
        {
            return await _unitOfWork.Categories
                .BuildQuery(c => c.ParentCategoryId == null)
                .OrderBy(c => c.CategoryName)
                .Select(c => new CategoryOptionViewModel
                {
                    Id = c.Id,
                    CategoryName = c.CategoryName
                })
                .ToListAsync();
        }

        public async Task CreateAsync(CategoryViewModel model, string actorUserId, string ipAddress)
        {
            if (string.IsNullOrWhiteSpace(model.CategoryName))
                throw new InvalidOperationException("Tên danh mục không được để trống.");

            string name = model.CategoryName.Trim();

            var parent = await GetValidParentAsync(model.ParentCategoryId, null);

            if (parent != null && !parent.IsActive && model.IsActive)
                throw new InvalidOperationException($"Danh mục {parent.CategoryName} đang ngừng hoạt động. Hãy mở lại danh mục này trước hoặc tạo danh mục con ở trạng thái ngừng hoạt động.");

            await EnsureNameAvailableAsync(name, model.ParentCategoryId, null);

            var category = new Category
            {
                CategoryName = name,
                Description = string.IsNullOrWhiteSpace(model.Description) ? null : model.Description.Trim(),
                IsActive = model.IsActive,
                ParentCategoryId = parent?.Id
            };

            await _unitOfWork.Categories.AddAsync(category);

            await _auditLogService.RecordAsync(
                "CreateCategory",
                "Category",
                null,
                parent == null
                    ? $"Thêm danh mục: {category.CategoryName}"
                    : $"Thêm danh mục con: {category.CategoryName} (thuộc {parent.CategoryName})",
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task UpdateAsync(CategoryViewModel model, string actorUserId, string ipAddress)
        {
            var category = await _unitOfWork.Categories.GetByIdAsync(model.Id);

            if (category == null)
                throw new InvalidOperationException("Danh mục không tồn tại.");

            if (Convert.ToBase64String(category.RowVersion) != model.RowVersion)
                throw new InvalidOperationException(CategoryConcurrencyMessage);

            if (string.IsNullOrWhiteSpace(model.CategoryName))
                throw new InvalidOperationException("Tên danh mục không được để trống.");

            string name = model.CategoryName.Trim();

            var parent = await GetValidParentAsync(model.ParentCategoryId, category.Id);

            if (parent != null && !parent.IsActive && category.IsActive)
                throw new InvalidOperationException($"Danh mục {parent.CategoryName} đang ngừng hoạt động nên không thể chuyển danh mục đang hoạt động vào.");

            await EnsureNameAvailableAsync(name, model.ParentCategoryId, category.Id);

            string? description = string.IsNullOrWhiteSpace(model.Description) ? null : model.Description.Trim();

            // Gộp mọi thay đổi trong 1 lần lưu vào 1 dòng nhật ký
            var changes = new List<string>();

            if (category.CategoryName != name)
                changes.Add($"Thay đổi tên từ {category.CategoryName} sang {name}.");

            if (category.Description != description)
                changes.Add("Thay đổi mô tả.");

            if (category.ParentCategoryId != parent?.Id)
            {
                string oldParentName = await GetParentNameAsync(category.ParentCategoryId);
                changes.Add($"Chuyển từ {oldParentName} sang {parent?.CategoryName ?? "danh mục cha"}.");
            }

            if (changes.Count == 0)
                return;

            string oldName = category.CategoryName;

            category.CategoryName = name;
            category.Description = description;
            category.ParentCategoryId = parent?.Id;

            await _auditLogService.RecordAsync(
                "UpdateCategory",
                "Category",
                category.Id.ToString(),
                $"Cập nhật danh mục {oldName}. {string.Join(" ", changes)}",
                ipAddress,
                actorUserId);

            try
            {
                await _unitOfWork.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                // Người khác lưu đúng lúc giữa bước kiểm tra và bước lưu
                throw new InvalidOperationException(CategoryConcurrencyMessage);
            }
        }

        private const string CategoryConcurrencyMessage = "Danh mục này vừa được cập nhật ở nơi khác. Vui lòng tải lại trang rồi sửa lại.";

        // Ngừng hoạt động: chỉ khi danh mục (và các danh mục con) chưa có đồ; danh mục con ngừng theo cha.
        // Mở lại: danh mục con chỉ mở được khi danh mục cha đang hoạt động.
        public async Task SetActiveAsync(int id, bool isActive, string actorUserId, string ipAddress)
        {
            var category = await _unitOfWork.Categories.GetByIdAsync(id);

            if (category == null)
                throw new InvalidOperationException("Danh mục không tồn tại.");

            // Trang của người bấm có thể đã cũ: người khác vừa đổi trạng thái trước đó
            if (category.IsActive == isActive)
                throw new InvalidOperationException(isActive ? "Danh mục này đã được mở lại hoạt động trước đó." : "Danh mục này đã ngừng hoạt động trước đó.");

            string description;

            if (isActive)
            {
                if (category.ParentCategoryId != null)
                {
                    var parent = await _unitOfWork.Categories.GetByIdAsync(category.ParentCategoryId.Value);

                    if (parent != null && !parent.IsActive)
                        throw new InvalidOperationException($"Danh mục cha {parent.CategoryName} đang ngừng hoạt động. Hãy mở lại danh mục cha trước.");
                }

                category.IsActive = true;
                description = $"Mở lại hoạt động danh mục: {category.CategoryName}";
            }
            else
            {
                bool hasItems = await _unitOfWork.Items
                    .BuildQuery(i => i.CategoryId == id || i.Category.ParentCategoryId == id)
                    .AnyAsync();

                if (hasItems)
                    throw new InvalidOperationException(category.ParentCategoryId == null
                        ? "Danh mục này hoặc danh mục con của nó đang có đồ cho thuê nên không thể ngừng hoạt động."
                        : "Danh mục đang có đồ cho thuê nên không thể ngừng hoạt động.");

                var activeChildren = await _unitOfWork.Categories
                    .BuildQuery(c => c.ParentCategoryId == id && c.IsActive)
                    .ToListAsync();

                category.IsActive = false;

                foreach (var child in activeChildren)
                    child.IsActive = false;

                description = activeChildren.Count == 0
                    ? $"Ngừng hoạt động danh mục: {category.CategoryName}"
                    : $"Ngừng hoạt động danh mục: {category.CategoryName} và {activeChildren.Count} danh mục con ({string.Join(", ", activeChildren.Select(c => c.CategoryName))})";
            }

            await _auditLogService.RecordAsync(
                "ToggleCategory",
                "Category",
                category.Id.ToString(),
                description,
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task DeleteAsync(int id, string actorUserId, string ipAddress)
        {
            var category = await _unitOfWork.Categories.GetByIdAsync(id);

            if (category == null)
                throw new InvalidOperationException("Danh mục không tồn tại.");

            bool hasChildren = await _unitOfWork.Categories
                .BuildQuery(c => c.ParentCategoryId == id)
                .AnyAsync();

            if (hasChildren)
                throw new InvalidOperationException("Danh mục đang có danh mục con nên không thể xóa. Hãy xóa các danh mục con trước.");

            bool hasItems = await _unitOfWork.Items
                .BuildQuery(i => i.CategoryId == id)
                .AnyAsync();

            if (hasItems)
                throw new InvalidOperationException("Danh mục đang có đồ cho thuê nên không thể xóa.");

            _unitOfWork.Categories.Delete(category);

            await _auditLogService.RecordAsync(
                "DeleteCategory",
                "Category",
                category.Id.ToString(),
                $"Xóa danh mục: {category.CategoryName}",
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        // Kiểm tra danh mục cha được chọn: phải tồn tại, phải là danh mục cấp 1,
        // và danh mục đang sửa không được có con (nếu không sẽ thành 3 cấp)
        private async Task<Category?> GetValidParentAsync(int? parentId, int? currentId)
        {
            if (parentId == null)
                return null;

            if (parentId == currentId)
                throw new InvalidOperationException("Danh mục không thể thuộc chính nó.");

            var parent = await _unitOfWork.Categories.GetByIdAsync(parentId.Value);

            if (parent == null)
                throw new InvalidOperationException("Danh mục cha không tồn tại.");

            if (parent.ParentCategoryId != null)
                throw new InvalidOperationException("Chỉ được chọn danh mục cấp 1 làm danh mục cha (hệ thống chỉ có 2 cấp).");

            if (currentId != null)
            {
                bool hasChildren = await _unitOfWork.Categories
                    .BuildQuery(c => c.ParentCategoryId == currentId)
                    .AnyAsync();

                if (hasChildren)
                    throw new InvalidOperationException("Danh mục này đang có danh mục con nên không thể chuyển vào danh mục khác.");
            }

            return parent;
        }

        // Tên chỉ cần không trùng trong cùng một danh mục cha (ví dụ "Khác" có thể có ở nhiều nhóm)
        private async Task EnsureNameAvailableAsync(string name, int? parentId, int? currentId)
        {
            bool nameExists = await _unitOfWork.Categories
                .BuildQuery(c => c.CategoryName == name && c.ParentCategoryId == parentId && c.Id != currentId)
                .AnyAsync();

            if (nameExists)
                throw new InvalidOperationException(parentId == null
                    ? "Tên danh mục đã tồn tại."
                    : "Danh mục cha này đã có danh mục con trùng tên.");
        }

        private async Task<string> GetParentNameAsync(int? parentId)
        {
            if (parentId == null)
                return "danh mục cha";

            var parent = await _unitOfWork.Categories.GetByIdAsync(parentId.Value);

            return parent?.CategoryName ?? "danh mục cũ";
        }
    }
}
