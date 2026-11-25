using Microsoft.EntityFrameworkCore;
using RentMate.Core.Interfaces.Persistence;
using RentMate.Core.Models;
using RentMate.Service.DTOs.Items;
using RentMate.Service.Interfaces;

namespace RentMate.Service.Services
{
    public class FavoriteService : IFavoriteService
    {
        private readonly IUnitOfWork _unitOfWork;

        public FavoriteService(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork;
        }

        public async Task<List<ItemDto>> GetMineAsync(string userId)
        {
            // Lấy id theo thứ tự lưu, rồi lấy đồ bằng cùng phép chiếu với ItemService
            var ids = await _unitOfWork.Favorites
                .BuildQuery(f => f.UserId == userId)
                .OrderByDescending(f => f.CreatedAt)
                .Select(f => f.ItemId)
                .ToListAsync();

            var items = await _unitOfWork.Items
                .BuildQuery(i => ids.Contains(i.Id))
                .Where(ItemService.IsPublic)
                .Select(ItemService.ToDto)
                .ToListAsync();

            return items.OrderBy(i => ids.IndexOf(i.ItemId)).ToList();
        }

        public async Task<List<int>> GetMyIdsAsync(string userId)
        {
            return await _unitOfWork.Favorites
                .BuildQuery(f => f.UserId == userId)
                .Select(f => f.ItemId)
                .ToListAsync();
        }

        public async Task<bool> AddAsync(string userId, int itemId)
        {
            bool visible = await _unitOfWork.Items
                .BuildQuery(i => i.Id == itemId)
                .Where(ItemService.IsPublic)
                .AnyAsync();

            if (!visible)
            {
                return false;
            }

            // Bấm tim 2 lần liên tiếp: đã có thì thôi
            bool exists = await _unitOfWork.Favorites
                .BuildQuery(f => f.UserId == userId && f.ItemId == itemId)
                .AnyAsync();

            if (!exists)
            {
                await _unitOfWork.Favorites.AddAsync(new Favorite { UserId = userId, ItemId = itemId });
                await _unitOfWork.SaveChangesAsync();
            }

            return true;
        }

        public async Task RemoveAsync(string userId, int itemId)
        {
            var ids = await _unitOfWork.Favorites
                .BuildQuery(f => f.UserId == userId && f.ItemId == itemId)
                .Select(f => f.Id)
                .ToListAsync();

            if (ids.Count == 0)
            {
                return;
            }

            foreach (var favorite in await _unitOfWork.Favorites.GetByIdsAsync(ids))
            {
                _unitOfWork.Favorites.Delete(favorite);
            }

            await _unitOfWork.SaveChangesAsync();
        }
    }
}
