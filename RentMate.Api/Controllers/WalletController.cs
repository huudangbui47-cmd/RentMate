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

        // GET api/wallet/deposits/5  (xem lại mã QR / nội dung chuyển khoản của yêu cầu nạp đang chờ)
        [HttpGet("deposits/{id}")]
        public async Task<IActionResult> GetDeposit(int id)
        {
            var deposit = await _walletService.GetPendingDepositAsync(GetUserId(), id);

            if (deposit == null)
                return NotFound();

            FillReceiverInfo(deposit);
            return Ok(deposit);
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

        // Duyệt nạp / rút: Admin làm trên trang quản trị (AdminSite > Nạp / rút tiền)

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
