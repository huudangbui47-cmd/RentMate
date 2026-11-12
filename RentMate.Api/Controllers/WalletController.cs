using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.DTOs.Wallet;
using RentMate.Service.Interfaces;
using System.Security.Claims;

namespace RentMate.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class WalletController : ControllerBase
    {
        private readonly IWalletService _walletService;
        private readonly IConfiguration _configuration;

        public WalletController(
            IWalletService walletService,
            IConfiguration configuration)
        {
            _walletService = walletService;
            _configuration = configuration;
        }

        // GET api/wallet
        [HttpGet]
        public async Task<IActionResult> GetSummary()
        {
            return await Execute(async () =>
                Ok(await _walletService.GetSummaryAsync(GetUserId())));
        }

        // GET api/wallet/transactions
        [HttpGet("transactions")]
        public async Task<IActionResult> GetHistory()
        {
            return Ok(await _walletService.GetHistoryAsync(GetUserId()));
        }

        // POST api/wallet/deposits
        [HttpPost("deposits")]
        public async Task<IActionResult> CreateDeposit(CreateDepositDto dto)
        {
            return await Execute(async () =>
            {
                var deposit = await _walletService.CreateDepositAsync(GetUserId(), dto.Amount);
                FillReceiverInfo(deposit);
                return Ok(deposit);
            });
        }

        // PUT api/wallet/bank-info
        [HttpPut("bank-info")]
        public async Task<IActionResult> UpdateBankInfo(UpdateBankInfoDto dto)
        {
            return await Execute(async () =>
            {
                await _walletService.UpdateBankInfoAsync(GetUserId(), dto);
                return NoContent();
            });
        }

        // POST api/wallet/withdrawals
        [HttpPost("withdrawals")]
        public async Task<IActionResult> CreateWithdraw(CreateWithdrawDto dto)
        {
            return await Execute(async () =>
                Ok(await _walletService.CreateWithdrawAsync(GetUserId(), dto.Amount)));
        }

        // ===== ADMIN =====

        // GET api/wallet/admin/pending
        [HttpGet("admin/pending")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetPending()
        {
            return Ok(await _walletService.GetPendingRequestsAsync());
        }

        // PUT api/wallet/admin/5/approve-deposit
        [HttpPut("admin/{id}/approve-deposit")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> ApproveDeposit(int id)
        {
            return await Execute(async () =>
                await _walletService.ApproveDepositAsync(id, GetUserId())
                    ? NoContent()
                    : NotFound());
        }

        // PUT api/wallet/admin/5/complete-withdraw
        [HttpPut("admin/{id}/complete-withdraw")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> CompleteWithdraw(int id)
        {
            return await Execute(async () =>
                await _walletService.CompleteWithdrawAsync(id, GetUserId())
                    ? NoContent()
                    : NotFound());
        }

        // PUT api/wallet/admin/5/reject
        [HttpPut("admin/{id}/reject")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Reject(int id, RejectWalletRequestDto dto)
        {
            return await Execute(async () =>
                await _walletService.RejectRequestAsync(id, GetUserId(), dto.Reason)
                    ? NoContent()
                    : NotFound());
        }

        // Tài khoản nhận tiền của RentMate, cấu hình ở mục "Wallet" trong appsettings.json
        private void FillReceiverInfo(DepositRequestDto deposit)
        {
            var section = _configuration.GetSection("Wallet");
            var bankId = section["BankId"];
            var accountNumber = section["AccountNumber"];
            var accountName = section["AccountName"];

            deposit.ReceiverBankName = section["BankName"];
            deposit.ReceiverAccountNumber = accountNumber;
            deposit.ReceiverAccountName = accountName;

            if (!string.IsNullOrEmpty(bankId) && !string.IsNullOrEmpty(accountNumber))
            {
                deposit.QrImageUrl =
                    $"https://img.vietqr.io/image/{bankId}-{accountNumber}-compact2.png" +
                    $"?amount={deposit.Amount:0}" +
                    $"&addInfo={Uri.EscapeDataString(deposit.Code)}" +
                    $"&accountName={Uri.EscapeDataString(accountName ?? string.Empty)}";
            }
        }

        private string GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        }

        private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
        {
            try
            {
                return await action();
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
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
    }
}
