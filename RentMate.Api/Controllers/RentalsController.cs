using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.DTOs.Rentals;
using RentMate.Service.Interfaces;
using System.Security.Claims;

namespace RentMate.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class RentalsController : ControllerBase
    {
        private readonly IRentalService _rentalService;

        public RentalsController(
            IRentalService rentalService)
        {
            _rentalService = rentalService;
        }

        // POST api/rentals
        [HttpPost]
        public async Task<IActionResult> Create(
            CreateRentalDto dto)
        {
            var userId = GetUserId();

            try
            {
                var rental =
                    await _rentalService.CreateAsync(
                        dto,
                        userId);

                return CreatedAtAction(
                    nameof(GetById),
                    new { id = rental.RentalId },
                    rental);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        // GET api/rentals/my
        [HttpGet("my")]
        public async Task<IActionResult> GetMyRentals()
        {
            var rentals =
                await _rentalService
                    .GetMyRentalsAsync(GetUserId());

            return Ok(rentals);
        }

        // GET api/rentals/1
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var rental =
                await _rentalService.GetByIdAsync(
                    id,
                    GetUserId());

            if (rental == null)
                return NotFound();

            return Ok(rental);
        }

        // PUT api/rentals/1/approve
        [HttpPut("{id}/approve")]
        public async Task<IActionResult> Approve(int id)
        {
            return await ExecuteAction(
                () => _rentalService.ApproveAsync(
                    id,
                    GetUserId()));
        }

        // PUT api/rentals/1/reject
        [HttpPut("{id}/reject")]
        public async Task<IActionResult> Reject(int id)
        {
            return await ExecuteAction(
                () => _rentalService.RejectAsync(
                    id,
                    GetUserId()));
        }

        // PUT api/rentals/1/pay  (người thuê trả tiền thuê + cọc bằng ví)
        [HttpPut("{id}/pay")]
        public async Task<IActionResult> Pay(int id)
        {
            return await ExecuteAction(
                () => _rentalService.PayAsync(
                    id,
                    GetUserId()));
        }

        // PUT api/rentals/1/cancel
        [HttpPut("{id}/cancel")]
        public async Task<IActionResult> Cancel(int id)
        {
            return await ExecuteAction(
                () => _rentalService.CancelAsync(
                    id,
                    GetUserId()));
        }

        // PUT api/rentals/1/pickup  (người thuê xác nhận đã nhận đồ)
        [HttpPut("{id}/pickup")]
        public async Task<IActionResult> Pickup(int id)
        {
            return await ExecuteAction(
                () => _rentalService.PickupAsync(
                    id,
                    GetUserId()));
        }

        // PUT api/rentals/1/return
        [HttpPut("{id}/return")]
        public async Task<IActionResult> Return(int id)
        {
            return await ExecuteAction(
                () => _rentalService.ReturnAsync(
                    id,
                    GetUserId()));
        }

        // PUT api/rentals/1/complete  body (không bắt buộc): { damageAmount, damageNote }
        // Chủ đồ: damageAmount = 0 hoàn đủ cọc; > 0 chờ người thuê đồng ý/khiếu nại.
        // Người thuê: tự hoàn tất khi chủ đồ quá 3 ngày không kiểm tra.
        [HttpPut("{id}/complete")]
        public async Task<IActionResult> Complete(int id, [FromBody] CompleteRentalDto? dto)
        {
            return await ExecuteAction(
                () => _rentalService.CompleteAsync(
                    id,
                    GetUserId(),
                    dto?.DamageAmount ?? 0,
                    dto?.DamageNote));
        }

        // PUT api/rentals/1/accept-damage  (người thuê đồng ý mức bồi thường)
        [HttpPut("{id}/accept-damage")]
        public async Task<IActionResult> AcceptDamage(int id)
        {
            return await ExecuteAction(
                () => _rentalService.AcceptDamageAsync(id, GetUserId()));
        }

        // PUT api/rentals/1/dispute  body: { reason }  (người thuê khiếu nại, quản trị viên phân xử)
        [HttpPut("{id}/dispute")]
        public async Task<IActionResult> Dispute(int id, DisputeRentalDto dto)
        {
            return await ExecuteAction(
                () => _rentalService.DisputeAsync(id, GetUserId(), dto.Reason));
        }

        private string GetUserId()
        {
            return User.FindFirstValue(
                ClaimTypes.NameIdentifier)!;
        }

        private async Task<IActionResult> ExecuteAction(
            Func<Task<bool>> action)
        {
            try
            {
                var result = await action();

                if (!result)
                    return NotFound();

                return NoContent();
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}