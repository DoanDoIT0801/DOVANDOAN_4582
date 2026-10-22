namespace DOVANDOAN_4582.model;

// DurationMinutes: thời gian mở điểm danh tính từ StartsAt. Bỏ trống = mở đến khi giảng viên đóng.
public record SessionRequest(
    string Title,
    DateTime StartsAt,
    double Latitude,
    double Longitude,
    double RadiusMeters,
    int? DurationMinutes = null);

public record ManualCheckInRequest(int StudentId);

public record ReopenRequest(int Minutes = 15);

// Điểm danh gửi dạng multipart/form-data vì có kèm ảnh.
public class CheckInForm
{
    public string QrToken { get; set; } = "";
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public IFormFile? Photo { get; set; }
}
