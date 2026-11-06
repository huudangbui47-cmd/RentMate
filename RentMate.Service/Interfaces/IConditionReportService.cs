using RentMate.Service.DTOs.ConditionReports;

namespace RentMate.Service.Interfaces
{
    public interface IConditionReportService
    {
        Task<ConditionReportDto> CreateAsync(
            int rentalId,
            CreateConditionReportDto dto,
            string userId);

        Task<List<ConditionReportDto>> GetByRentalAsync(
            int rentalId,
            string userId);
    }
}
