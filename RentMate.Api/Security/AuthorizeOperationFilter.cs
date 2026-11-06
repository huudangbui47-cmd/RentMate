using Microsoft.AspNetCore.Authorization;
using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace RentMate.Api.Security
{
    /// <summary>
    /// Swagger chỉ hiện biểu tượng khóa ở những API thật sự yêu cầu JWT.
    /// </summary>
    public sealed class AuthorizeOperationFilter : IOperationFilter
    {
        public void Apply(OpenApiOperation operation, OperationFilterContext context)
        {
            bool isAnonymous =
                context.MethodInfo.IsDefined(typeof(AllowAnonymousAttribute), true) ||
                context.MethodInfo.DeclaringType?.IsDefined(typeof(AllowAnonymousAttribute), true) == true;

            if (isAnonymous)
                return;

            bool needsAuthentication =
                context.MethodInfo.IsDefined(typeof(AuthorizeAttribute), true) ||
                context.MethodInfo.DeclaringType?.IsDefined(typeof(AuthorizeAttribute), true) == true;

            if (!needsAuthentication)
                return;

            operation.Security ??= new List<OpenApiSecurityRequirement>();
            operation.Security.Add(new OpenApiSecurityRequirement
            {
                [new OpenApiSecurityScheme
                {
                    Reference = new OpenApiReference
                    {
                        Type = ReferenceType.SecurityScheme,
                        Id = "Bearer"
                    }
                }] = Array.Empty<string>()
            });
        }
    }
}
