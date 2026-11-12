namespace RentMate.Core.Enums
{
    public enum WalletTransactionType
    {
        Deposit = 1,        // Nạp tiền vào ví
        Withdraw = 2,       // Rút tiền về ngân hàng
        RentalPayment = 3,  // Trừ tiền thuê + cọc khi thanh toán đơn
        RentalIncome = 4,   // Chủ đồ nhận tiền thuê
        DepositRefund = 5,  // Hoàn tiền cọc cho người thuê
        Compensation = 6,   // Chủ đồ nhận tiền bồi thường
        Refund = 7          // Hoàn tiền khi đơn bị từ chối / hủy
    }
}
