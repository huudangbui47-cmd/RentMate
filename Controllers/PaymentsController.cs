using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Api.DTOs.Payments;
using RentMate.Api.Services.Interfaces;
using System.Security.Claims;

namespace RentMate.Api.Controllers
{
    [ApiController]
    [Authorize]
    [Route("api/rentals/{rentalId:int}/payments")]
    public class PaymentsController : ControllerBase
    {
        private readonly IPaymentService _paymentService;

        public PaymentsController(
            IPaymentService paymentService)
        {
            _paymentService = paymentService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll(
            int rentalId)
        {
            try
            {
                var payments =
                    await _paymentService
                        .GetByRentalAsync(
                            rentalId,
                            GetUserId());

                return Ok(payments);
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

        [HttpPost]
        public async Task<IActionResult> Pay(
            int rentalId,
            PayPaymentDto dto)
        {
            try
            {
                var payment =
                    await _paymentService.PayAsync(
                        rentalId,
                        dto,
                        GetUserId());

                return Ok(payment);
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