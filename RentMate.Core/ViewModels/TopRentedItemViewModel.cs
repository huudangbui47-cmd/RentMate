namespace RentMate.Core.ViewModels
{
    public class TopRentedItemViewModel
    {
        public string ItemName { get; set; } = string.Empty;
        public string OwnerName { get; set; } = string.Empty;
        public int RentalCount { get; set; }
    }
}
