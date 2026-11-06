namespace RentMate.Core.ViewModels
{
    public class MonthlyRevenueViewModel
    {
        public int Year { get; set; }
        public int Month { get; set; }
        public decimal Revenue { get; set; }

        public string Label => $"{Month:00}/{Year}";
    }
}
