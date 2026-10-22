using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using DOVANDOAN_4582.model;

namespace DOVANDOAN_4582.Services;

public static class DbSeeder
{
    // Tạo tài khoản Admin đầu tiên từ cấu hình SeedAdmin (mật khẩu lưu trong user secrets).
    public static async Task SeedAsync(ApplicationDbContext db, IConfiguration config, PasswordHasher<AppUser> hasher)
    {
        var username = config["SeedAdmin:Username"];
        var password = config["SeedAdmin:Password"];
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password)) return;
        if (await db.Users.AnyAsync(u => u.Role == UserRole.Admin)) return;

        var admin = new AppUser
        {
            Username = username,
            Email = config["SeedAdmin:Email"] ?? "admin@local",
            FullName = "Quản trị viên",
            Role = UserRole.Admin,
            IsActive = true
        };
        admin.PasswordHash = hasher.HashPassword(admin, password);
        db.Users.Add(admin);
        await db.SaveChangesAsync();
    }
}
