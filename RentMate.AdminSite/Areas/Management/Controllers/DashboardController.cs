using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    [Area("Management")]
    [Authorize(Roles = "Admin,Manager")]
    public class DashboardController : Controller
    {
        private readonly IDashboardService _dashboardService;

        public DashboardController(IDashboardService dashboardService)
        {
            _dashboardService = dashboardService;
        }

        public async Task<IActionResult> Index()
        {
            var model = await _dashboardService.GetAsync();

            return View(model);
        }
    }
}
