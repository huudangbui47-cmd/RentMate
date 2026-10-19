using RentMate.Api.DTOs.ConditionReports;

namespace RentMate.Api.Services.Interfaces
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