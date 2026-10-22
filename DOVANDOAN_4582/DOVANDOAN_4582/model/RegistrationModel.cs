namespace DOVANDOAN_4582.model;

public record RegisterRequest(string Username, string Email, string Password, string FullName, UserRole Role);

public record UserUpdateRequest(string Email, string FullName, UserRole Role, bool IsActive);
