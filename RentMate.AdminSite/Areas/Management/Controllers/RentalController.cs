using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Core.Enums;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    [Area("Management")]
    [Authorize(Roles = "Admin,Manager")]
    public class RentalController : ManagementControllerBase
    {
        private readonly IRentalService _rentalService;

        public RentalController(IRentalService rentalService)
        {
            _rentalService = rentalService;
        }

        public async Task<IActionResult> Index(string? searchTerm, RentalStatus? status, int page = 1)
        {
            var model = await _rentalService.SearchAsync(searchTerm, status, page);

            return View(model);
        }

        public async Task<IActionResult> Details(int id)
        {
            var model = await _rentalService.GetDetailsAsync(id);

            if (model == null)
                return NotFound();

            return View(model);
        }
    }
}
