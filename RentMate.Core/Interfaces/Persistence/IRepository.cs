using RentMate.Core.Models;
using System.Linq.Expressions;

namespace RentMate.Core.Interfaces.Persistence
{
    public interface IRepository<T> where T : BaseEntity
    {
        IQueryable<T> BuildQuery(Expression<Func<T, bool>> predicate);
        Task<T?> GetByIdAsync(int id);
        Task<List<T>> GetByIdsAsync(IEnumerable<int> ids);
        Task AddAsync(T entity);
        void Update(T entity);
        void Delete(T entity);
        Task<bool> ExistsAsync(int id);
    }
}
