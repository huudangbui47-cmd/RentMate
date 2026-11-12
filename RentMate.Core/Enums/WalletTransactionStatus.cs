namespace RentMate.Core.Enums
{
    public enum WalletTransactionStatus
    {
        Pending = 1,    // Chờ admin xử lý (nạp, rút)
        Completed = 2,  // Đã tính vào số dư
        Rejected = 3    // Bị từ chối, không tính
    }
}
