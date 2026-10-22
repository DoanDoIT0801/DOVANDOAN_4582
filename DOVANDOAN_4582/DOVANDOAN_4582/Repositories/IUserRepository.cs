using DOVANDOAN_4582.model;

namespace DOVANDOAN_4582.Repositories;

public interface IUserRepository
{
    IQueryable<AppUser> Users();
    IQueryable<OtpCode> OtpCodes();
    void Add(AppUser user);
    void Remove(AppUser user);
    void AddOtp(OtpCode otp);
    Task<bool> SaveAsync();
}
