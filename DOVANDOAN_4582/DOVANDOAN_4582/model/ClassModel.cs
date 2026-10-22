namespace DOVANDOAN_4582.model;

public record SubjectRequest(string Code, string Name);

// TeacherId bị bỏ qua khi giảng viên tự tạo lớp (luôn gán chính giảng viên đó).
public record ClassRequest(
    string Name,
    int SubjectId,
    int TeacherId,
    string? Room = null,
    string? Schedule = null,
    int PlannedSessions = 15);

public record EnrollRequest(int StudentId);

// Một dòng trong báo cáo vắng của lớp.
public record AbsenceRow(
    int StudentId,
    string Username,
    string FullName,
    string Email,
    int TotalSessions,
    int PresentSessions,
    int ExcusedSessions,
    int AbsentSessions,
    double AbsentRate,
    int RemainingAbsences,
    bool IsWarned);
