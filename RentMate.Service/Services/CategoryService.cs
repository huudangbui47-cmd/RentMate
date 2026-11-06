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
        public async Task<List<CategoryDto>> GetAllAsync()
        {
            return await _unitOfWork.Categories
                .BuildQuery(c => c.IsActive)
                .Select(c => new CategoryDto
                {
                    CategoryId = c.Id,
                    CategoryName = c.CategoryName,
                    Description = c.Description,
                    IsActive = c.IsActive
                })
                .ToListAsync();
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
                    IsActive = c.IsActive
                })
                .FirstOrDefaultAsync();
        }

        public async Task<CategoryDto> CreateAsync(CreateCategoryDto dto)
        {
            var exists = await _unitOfWork.Categories
                .BuildQuery(c => c.CategoryName == dto.CategoryName)
                .AnyAsync();

            if (exists)
            {
                throw new ArgumentException(
                    "Category already exists.");
            }

            var category = new Category
            {
                CategoryName = dto.CategoryName.Trim(),
                Description = dto.Description,
                IsActive = true
            };

            await _unitOfWork.Categories.AddAsync(category);

            await _unitOfWork.SaveChangesAsync();

            return new CategoryDto
            {
                CategoryId = category.Id,
                CategoryName = category.CategoryName,
                Description = category.Description,
                IsActive = category.IsActive
            };
        }

        // =========================
        // TRANG QUẢN TRỊ
        // =========================
        public async Task<List<CategoryViewModel>> GetAllForManagementAsync()
        {
            return await _unitOfWork.Categories
                .BuildQuery(c => true)
                .OrderByDescending(c => c.IsActive).ThenBy(c => c.CategoryName)
                .Select(c => new CategoryViewModel
                {
                    Id = c.Id,
                    CategoryName = c.CategoryName,
                    Description = c.Description,
                    IsActive = c.IsActive,
                    ItemCount = c.Items.Count
                })
                .ToListAsync();
        }

        public async Task<CategoryViewModel?> GetForEditAsync(int id)
        {
            return await _unitOfWork.Categories
                .BuildQuery(c => c.Id == id)
                .Select(c => new CategoryViewModel
                {
                    Id = c.Id,
                    CategoryName = c.CategoryName,
                    Description = c.Description,
                    IsActive = c.IsActive,
                    ItemCount = c.Items.Count
                })
                .FirstOrDefaultAsync();
        }

        public async Task CreateAsync(CategoryViewModel model, string actorUserId, string ipAddress)
        {
            if (string.IsNullOrWhiteSpace(model.CategoryName))
                throw new InvalidOperationException("Tên danh mục không được để trống.");

            string name = model.CategoryName.Trim();

            bool nameExists = await _unitOfWork.Categories
                .BuildQuery(c => c.CategoryName == name)
                .AnyAsync();

            if (nameExists)
                throw new InvalidOperationException("Tên danh mục đã tồn tại.");

            var category = new Category
            {
                CategoryName = name,
                Description = string.IsNullOrWhiteSpace(model.Description) ? null : model.Description.Trim(),
                IsActive = model.IsActive
            };

            await _unitOfWork.Categories.AddAsync(category);

            await _auditLogService.RecordAsync(
                "CreateCategory",
                "Category",
                null,
                $"Thêm danh mục: {category.CategoryName}",
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task UpdateAsync(CategoryViewModel model, string actorUserId, string ipAddress)
        {
            var category = await _unitOfWork.Categories.GetByIdAsync(model.Id);

            if (category == null)
                throw new InvalidOperationException("Danh mục không tồn tại.");

            if (string.IsNullOrWhiteSpace(model.CategoryName))
                throw new InvalidOperationException("Tên danh mục không được để trống.");

            string name = model.CategoryName.Trim();

            bool nameExists = await _unitOfWork.Categories
                .BuildQuery(c => c.CategoryName == name && c.Id != model.Id)
                .AnyAsync();

            if (nameExists)
                throw new InvalidOperationException("Tên danh mục đã tồn tại.");

            string? description = string.IsNullOrWhiteSpace(model.Description) ? null : model.Description.Trim();

            // Gộp mọi thay đổi trong 1 lần lưu vào 1 dòng nhật ký
            var changes = new List<string>();

            if (category.CategoryName != name)
                changes.Add($"Thay đổi tên từ {category.CategoryName} sang {name}.");

            if (category.Description != description)
                changes.Add("Thay đổi mô tả.");

            if (category.IsActive != model.IsActive)
                changes.Add(model.IsActive ? "Bật danh mục." : "Tắt danh mục.");

            if (changes.Count == 0)
                return;

            string oldName = category.CategoryName;

            category.CategoryName = name;
            category.Description = description;
            category.IsActive = model.IsActive;

            await _auditLogService.RecordAsync(
                "UpdateCategory",
                "Category",
                category.Id.ToString(),
                $"Cập nhật danh mục {oldName}. {string.Join(" ", changes)}",
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        // Không xóa cứng vì danh mục còn đồ cho thuê tham chiếu, chỉ bật/tắt
        public async Task ToggleActiveAsync(int id, string actorUserId, string ipAddress)
        {
            var category = await _unitOfWork.Categories.GetByIdAsync(id);

            if (category == null)
                throw new InvalidOperationException("Danh mục không tồn tại.");

            category.IsActive = !category.IsActive;

            await _auditLogService.RecordAsync(
                "ToggleCategory",
                "Category",
                category.Id.ToString(),
                $"{(category.IsActive ? "Bật" : "Tắt")} danh mục: {category.CategoryName}",
                ipAddress,
                actorUserId);

            await _unitOfWork.SaveChangesAsync();
        }

        public async Task DeleteAsync(int id, string actorUserId, string ipAddress)
        {
            var category = await _unitOfWork.Categories.GetByIdAsync(id);

            if (category == null)
                throw new InvalidOperationException("Danh mục không tồn tại.");

            bool hasItems = await _unitOfWork.Items
                .BuildQuery(i => i.CategoryId == id)
                .AnyAsync();

            if (hasItems)
                throw new InvalidOperationException("Danh mục đang có đồ cho thuê nên không thể xóa. Bạn có thể tắt danh mục thay vì xóa.");

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
    }
}
