using Microsoft.EntityFrameworkCore;
using RentMate.Api.Data;
using RentMate.Api.DTOs.Items;
using RentMate.Api.Models;
using RentMate.Api.Models.Enums;
using RentMate.Api.Services.Interfaces;

namespace RentMate.Api.Services
{
    public class ItemService : IItemService
    {
        private readonly ApplicationDbContext _context;

        public ItemService(ApplicationDbContext context)
        {
            _context = context;
        }

        // =========================
        // GET ALL
        // =========================
        public async Task<List<ItemDto>> GetAllAsync()
        {
            return await _context.Items
                .AsNoTracking()
                .Where(i => i.Status != ItemStatus.Hidden)
                .Include(i => i.Category)
                .Include(i => i.Owner)
                .Select(i => new ItemDto
                {
                    ItemId = i.ItemId,
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
            return await _context.Items
                .AsNoTracking()
                .Where(i =>
                    i.ItemId == id &&
                    i.Status != ItemStatus.Hidden)
                .Include(i => i.Category)
                .Include(i => i.Owner)
                .Select(i => new ItemDto
                {
                    ItemId = i.ItemId,
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
            var categoryExists =
                await _context.Categories.AnyAsync(c =>
                    c.CategoryId == dto.CategoryId &&
                    c.IsActive);

            if (!categoryExists)
            {
                throw new ArgumentException(
                    "Category does not exist.");
            }

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

            _context.Items.Add(item);

            await _context.SaveChangesAsync();

            return (await GetByIdAsync(item.ItemId))!;
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
                await _context.Items.FindAsync(id);

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

            var categoryExists =
                await _context.Categories.AnyAsync(c =>
                    c.CategoryId == dto.CategoryId &&
                    c.IsActive);

            if (!categoryExists)
            {
                throw new ArgumentException(
                    "Category does not exist.");
            }

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

            await _context.SaveChangesAsync();

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
                await _context.Items.FindAsync(id);

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

            await _context.SaveChangesAsync();

            return true;
        }
    }
}