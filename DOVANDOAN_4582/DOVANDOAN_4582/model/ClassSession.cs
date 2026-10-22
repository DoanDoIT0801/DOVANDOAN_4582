namespace DOVANDOAN_4582.model;

public class ClassSession
{
    public int Id { get; set; }
    public int ClassRoomId { get; set; }
    public ClassRoom ClassRoom { get; set; } = null!;
    public string Title { get; set; } = "";
    public DateTime StartsAt { get; set; }
    // Hết giờ này thì không nhận điểm danh nữa, kể cả khi giảng viên chưa bấm đóng.
    public DateTime? EndsAt { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double RadiusMeters { get; set; }
    public string QrToken { get; set; } = "";
    public bool IsOpen { get; set; } = true;

    public bool AcceptsCheckIn(DateTime utcNow) => IsOpen && (EndsAt is null || utcNow < EndsAt);
}
