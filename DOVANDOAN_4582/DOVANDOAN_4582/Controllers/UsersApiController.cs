using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DOVANDOAN_4582.model;
using DOVANDOAN_4582.Repositories;

namespace DOVANDOAN_4582.Controllers;

[ApiController]
[Route("api/users")]
[Authorize(Roles = nameof(UserRole.Admin))]
public class UsersApiController(IUserRepository users, PasswordHasher<AppUser> hasher, ApplicationDbContext db) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var list = await users.Users().OrderBy(u => u.Id).ToListAsync();
        return Ok(list.Select(ToDto));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetOne(int id)
    {
        var u = await users.Users().FirstOrDefaultAsync(x => x.Id == id);
        return u is null ? NotFound() : Ok(ToDto(u));
    }

    [HttpPost]
    public async Task<IActionResult> Create(RegisterRequest req)
    {
        if (req.Password.Length < 6) return BadRequest("Mật khẩu tối thiểu 6 ký tự.");
        if (await users.Users().AnyAsync(u => u.Username == req.Username || u.Email == req.Email))
            return Conflict("Tên đăng nhập hoặc email đã tồn tại.");

        var u = new AppUser
        {
            Username = req.Username.Trim(),
            Email = req.Email.Trim(),
            FullName = req.FullName.Trim(),
            Role = req.Role,
            IsActive = true
        };
        u.PasswordHash = hasher.HashPassword(u, req.Password);
        users.Add(u);
        await users.SaveAsync();
        return Ok(ToDto(u));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, UserUpdateRequest req)
    {
        var u = await users.Users().FirstOrDefaultAsync(x => x.Id == id);
        if (u is null) return NotFound();

        u.Email = req.Email.Trim();
        u.FullName = req.FullName.Trim();
        u.Role = req.Role;
        u.IsActive = req.IsActive;
        if (!await users.SaveAsync()) return Conflict("Email đã được dùng bởi tài khoản khác.");
        return Ok(ToDto(u));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        if (id == CurrentUserId)
            return BadRequest("Không thể tự xoá tài khoản quản trị đang đăng nhập.");

        var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id);
        if (u is null) return NotFound("Không tìm thấy người dùng.");

        // Kiểm tra xem giảng viên có đang phụ trách lớp học nào không
        var hasClasses = await db.ClassRooms.AnyAsync(c => c.TeacherId == id);
        if (hasClasses)
            return Conflict("Không thể xoá: Giảng viên này đang phụ trách lớp học. Vui lòng xoá hoặc chuyển lớp trước.");

        // Dọn dẹp toàn bộ dữ liệu phụ thuộc để xoá tài khoản sạch sẽ
        var otps = await db.OtpCodes.Where(o => o.UserId == id).ToListAsync();
        if (otps.Count > 0) db.OtpCodes.RemoveRange(otps);

        var enrollments = await db.Enrollments.Where(e => e.StudentId == id).ToListAsync();
        if (enrollments.Count > 0) db.Enrollments.RemoveRange(enrollments);

        var leaves = await db.LeaveRequests.Where(l => l.StudentId == id).ToListAsync();
        if (leaves.Count > 0) db.LeaveRequests.RemoveRange(leaves);

        var attends = await db.Attendances.Where(a => a.StudentId == id).ToListAsync();
        if (attends.Count > 0) db.Attendances.RemoveRange(attends);

        db.Users.Remove(u);
        await db.SaveChangesAsync();
        return NoContent();
    }

    private static object ToDto(AppUser u) => new { u.Id, u.Username, u.Email, u.FullName, u.Role, u.IsActive };
}
