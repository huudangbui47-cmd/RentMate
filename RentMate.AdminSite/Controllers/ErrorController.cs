using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace RentMate.AdminSite.Controllers
{
    [AllowAnonymous]
    public class ErrorController : Controller
    {
        [Route("Error/{statusCode:int}")]
        public IActionResult Index(int statusCode)
        {
            Response.StatusCode = statusCode;

            return statusCode switch
            {
                403 => View("403"),
                404 => View("404"),
                _ => View("500")
            };
        }
    }
}
