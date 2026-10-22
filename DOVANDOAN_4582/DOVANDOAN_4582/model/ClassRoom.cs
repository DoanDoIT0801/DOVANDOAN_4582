namespace DOVANDOAN_4582.model;

public class ClassRoom
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public int SubjectId { get; set; }
    public Subject Subject { get; set; } = null!;
    public int TeacherId { get; set; }
    public AppUser Teacher { get; set; } = null!;
    public string? Room { get; set; }
    public string? Schedule { get; set; }
    // Số buổi dự kiến của học phần, dùng để tính số buổi sinh viên còn được nghỉ.
    public int PlannedSessions { get; set; } = 15;
    public List<Enrollment> Enrollments { get; set; } = [];
}
