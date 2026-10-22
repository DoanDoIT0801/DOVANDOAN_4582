namespace DOVANDOAN_4582.model;

public record LoginRequest(string Username, string Password);

public record VerifyOtpRequest(string Username, string Code);

// Account: tên đăng nhập hoặc email.
public record ForgotPasswordRequest(string Account);

public record ResetPasswordRequest(string Account, string Code, string NewPassword);
