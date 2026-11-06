using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RentMate.Service.Interfaces;

namespace RentMate.AdminSite.Areas.Management.Controllers
{
    [Area("Management")]
    [Authorize(Roles = "Admin")]
    public class AuditLogController : Controller
    {
        private readonly IAuditLogService _auditLogService;

        public AuditLogController(IAuditLogService auditLogService)
        {
            _auditLogService = auditLogService;
        }

        public async Task<IActionResult> Index(string? userId, DateTime? fromDate, DateTime? toDate, int page = 1)
        {
            var model = await _auditLogService.SearchAsync(userId, fromDate, toDate, page);

            return View(model);
        }
    }
}
