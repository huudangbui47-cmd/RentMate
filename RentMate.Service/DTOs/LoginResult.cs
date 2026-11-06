using RentMate.Core.Enums;

namespace RentMate.Service.DTOs
{
    public class LoginResult
    {
        public LoginStatus Status { get; set; }

        public AuthenticatedUser? User { get; set; }

        public DateTimeOffset? LockoutEnd { get; set; }
    }
}
