namespace DOVANDOAN_4582.model;

public class Enrollment
{
    public int Id { get; set; }
    public int ClassRoomId { get; set; }
    public ClassRoom ClassRoom { get; set; } = null!;
    public int StudentId { get; set; }
    public AppUser Student { get; set; } = null!;
}
