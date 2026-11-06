using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.DTOs.ConditionReports;
using RentMate.Service.Interfaces;
using System.Security.Claims;

namespace RentMate.Api.Controllers
{
    [Route(
        "api/rentals/{rentalId:int}/condition-reports")]
    [ApiController]
    [Authorize]
    public class ConditionReportsController
        : ControllerBase
    {
        private readonly IConditionReportService
            _conditionReportService;

        public ConditionReportsController(
            IConditionReportService conditionReportService)
        {
            _conditionReportService =
                conditionReportService;
        }

        // GET:
        // api/rentals/1/condition-reports
        [HttpGet]
        public async Task<IActionResult> GetAll(
            int rentalId)
        {
            try
            {
                var reports =
                    await _conditionReportService
                        .GetByRentalAsync(
                            rentalId,
                            GetUserId());

                return Ok(reports);
            }
            catch (ArgumentException ex)
            {
                return NotFound(ex.Message);
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
        }

        // POST:
        // api/rentals/1/condition-reports
        [HttpPost]
        public async Task<IActionResult> Create(
            int rentalId,
            CreateConditionReportDto dto)
        {
            try
            {
                var report =
                    await _conditionReportService
                        .CreateAsync(
                            rentalId,
                            dto,
                            GetUserId());

                return Ok(report);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
        }

        private string GetUserId()
        {
            return User.FindFirstValue(
                ClaimTypes.NameIdentifier)!;
        }
    }
}