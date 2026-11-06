using RentMate.Core.ViewModels;

namespace RentMate.Service.Interfaces
{
    public interface IDashboardService
    {
        Task<DashboardViewModel> GetAsync();
    }
}
