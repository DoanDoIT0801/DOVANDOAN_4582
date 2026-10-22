using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using DOVANDOAN_4582.model;

namespace DOVANDOAN_4582.Controllers;

public abstract class ApiControllerBase : ControllerBase
{
    protected int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    protected bool IsAdmin => User.IsInRole(nameof(UserRole.Admin));
}
