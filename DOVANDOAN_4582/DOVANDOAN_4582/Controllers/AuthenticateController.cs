using System.Security.Cryptography;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DOVANDOAN_4582.model;
using DOVANDOAN_4582.Repositories;
using DOVANDOAN_4582.Services;

namespace DOVANDOAN_4582.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthenticateController(
    IUserRepository users,
    PasswordHasher<AppUser> hasher,
    JwtService jwt,
    EmailService email) : ApiControllerBase
{
    // Đăng ký: tài khoản chưa kích hoạt, gửi OTP tới email để xác nhận.
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterRequest req)
    {
        if (req.Role == UserRole.Admin) return BadRequest("Không thể tự đăng ký tài khoản quản trị.");
        if (req.Password.Length < 6) return BadRequest("Mật khẩu tối thiểu 6 ký tự.");
        if (await users.Users().AnyAsync(u => u.Username == req.Username || u.Email == req.Email))
            return Conflict("Tên đăng nhập hoặc email đã tồn tại.");

        var user = new AppUser
        {
            Username = req.Username.Trim(),
            Email = req.Email.Trim(),
            FullName = req.FullName.Trim(),
            Role = req.Role,
            IsActive = false
        };
        user.PasswordHash = hasher.HashPassword(user, req.Password);
        users.Add(user);
        await users.SaveAsync();

        await SendOtpAsync(user, OtpPurpose.Register);
        return Ok(new { message = "Đã gửi mã OTP xác nhận tới email." });
    }

    [HttpPost("register/verify")]
    public async Task<IActionResult> VerifyRegister(VerifyOtpRequest req)
    {
        var user = await users.Users().FirstOrDefaultAsync(u => u.Username == req.Username);
        if (user is null) return NotFound();
        if (user.IsActive) return BadRequest("Tài khoản đã được xác nhận.");
        if (!await ConsumeOtpAsync(user, OtpPurpose.Register, req.Code))
            return BadRequest("Mã OTP không đúng hoặc đã hết hạn.");

        user.IsActive = true;
        await users.SaveAsync();
        return Ok(new { message = "Đăng ký thành công. Hãy đăng nhập." });
    }

    // Đăng nhập bước 1: kiểm tra tên đăng nhập + mật khẩu, rồi gửi OTP.
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest req)
    {
        var user = await users.Users().FirstOrDefaultAsync(u => u.Username == req.Username);
        if (user is null || !user.IsActive) return Unauthorized("Sai tài khoản hoặc chưa xác nhận email.");
        if (hasher.VerifyHashedPassword(user, user.PasswordHash, req.Password) == PasswordVerificationResult.Failed)
            return Unauthorized("Sai tài khoản hoặc mật khẩu.");

        await SendOtpAsync(user, OtpPurpose.Login);
        return Ok(new { message = "Đã gửi mã OTP đăng nhập tới email." });
    }

    // Đăng nhập bước 2: kiểm tra OTP rồi cấp JWT.
    [HttpPost("login/verify")]
    public async Task<IActionResult> VerifyLogin(VerifyOtpRequest req)
    {
        var user = await users.Users().FirstOrDefaultAsync(u => u.Username == req.Username);
        if (user is null || !user.IsActive) return Unauthorized("Sai tài khoản hoặc chưa xác nhận email.");
        if (!await ConsumeOtpAsync(user, OtpPurpose.Login, req.Code))
            return Unauthorized("Mã OTP không đúng hoặc đã hết hạn.");

        return Ok(new { token = jwt.CreateToken(user), role = user.Role, fullName = user.FullName });
    }

    // Quên mật khẩu bước 1: gửi OTP về email của tài khoản.
    // Luôn trả cùng một thông báo để không lộ tài khoản nào tồn tại.
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest req)
    {
        var user = await FindByAccountAsync(req.Account);
        if (user is not null && user.IsActive) await SendOtpAsync(user, OtpPurpose.ResetPassword);
        return Ok(new { message = "Nếu tài khoản tồn tại, mã OTP đặt lại mật khẩu đã được gửi tới email đăng ký." });
    }

    // Quên mật khẩu bước 2: kiểm tra OTP rồi đặt mật khẩu mới.
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest req)
    {
        if (req.NewPassword.Length < 6) return BadRequest("Mật khẩu mới tối thiểu 6 ký tự.");
        var user = await FindByAccountAsync(req.Account);
        if (user is null || !user.IsActive || !await ConsumeOtpAsync(user, OtpPurpose.ResetPassword, req.Code))
            return BadRequest("Mã OTP không đúng hoặc đã hết hạn.");

        user.PasswordHash = hasher.HashPassword(user, req.NewPassword);
        await users.SaveAsync();
        return Ok(new { message = "Đã đặt lại mật khẩu. Hãy đăng nhập bằng mật khẩu mới." });
    }

    private Task<AppUser?> FindByAccountAsync(string account)
    {
        var value = account.Trim();
        return users.Users().FirstOrDefaultAsync(u => u.Username == value || u.Email == value);
    }

    private async Task SendOtpAsync(AppUser user, OtpPurpose purpose)
    {
        var stale = await users.OtpCodes().Where(o => o.UserId == user.Id && o.Purpose == purpose && !o.IsUsed).ToListAsync();
        foreach (var s in stale) s.IsUsed = true;

        var code = RandomNumberGenerator.GetInt32(100000, 1000000).ToString();
        users.AddOtp(new OtpCode
        {
            UserId = user.Id,
            Code = code,
            Purpose = purpose,
            ExpiresAt = DateTime.UtcNow.AddMinutes(5)
        });
        await users.SaveAsync();

        var action = purpose switch
        {
            OtpPurpose.Register => "xác nhận đăng ký",
            OtpPurpose.Login => "đăng nhập",
            _ => "đặt lại mật khẩu"
        };
        await email.SendAsync(
            user.Email,
            $"Mã OTP {action} - Điểm danh SV",
            $"Mã OTP {action} của bạn là {code}. Có hiệu lực trong 5 phút.\n" +
            "Nếu bạn không thực hiện yêu cầu này, hãy bỏ qua email.");
    }

    // Kiểm tra OTP mới nhất. Sai 5 lần thì mã bị vô hiệu.
    private async Task<bool> ConsumeOtpAsync(AppUser user, OtpPurpose purpose, string code)
    {
        var otp = await users.OtpCodes()
            .Where(o => o.UserId == user.Id && o.Purpose == purpose && !o.IsUsed)
            .OrderByDescending(o => o.Id)
            .FirstOrDefaultAsync();
        if (otp is null || otp.ExpiresAt < DateTime.UtcNow) return false;

        if (otp.Code != code)
        {
            otp.Attempts++;
            if (otp.Attempts >= 5) otp.IsUsed = true;
            await users.SaveAsync();
            return false;
        }

        otp.IsUsed = true;
        await users.SaveAsync();
        return true;
    }
}
