namespace DOVANDOAN_4582.model;

public class Attendance
{
    public int Id { get; set; }
    public int ClassSessionId { get; set; }
    public ClassSession ClassSession { get; set; } = null!;
    public int StudentId { get; set; }
    public AppUser Student { get; set; } = null!;
    public DateTime CheckedInAt { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double DistanceMeters { get; set; }
    public string? PhotoPath { get; set; }
    // true khi giảng viên điểm danh hộ (ví dụ sinh viên hỏng điện thoại).
    public bool IsManual { get; set; }
}
