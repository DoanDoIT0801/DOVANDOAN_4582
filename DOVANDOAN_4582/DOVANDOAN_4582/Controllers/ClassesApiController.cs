using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DOVANDOAN_4582.model;
using DOVANDOAN_4582.Repositories;
using DOVANDOAN_4582.Services;

namespace DOVANDOAN_4582.Controllers;

[ApiController]
[Route("api/classes")]
[Authorize]
public class ClassesApiController(
    IClassRepository classes,
    ISessionRepository sessions,
    ILeaveRequestRepository leaves,
    IUserRepository users,
    EmailService email,
    IConfiguration config) : ApiControllerBase
{
    private const string NoAccess = "Không tìm thấy lớp hoặc bạn không có quyền.";
    private const string TeacherOrAdmin = nameof(UserRole.Admin) + "," + nameof(UserRole.GiangVien);

    private double Threshold => config.GetValue("Attendance:WarningRate", 0.2);

    // Số buổi được phép vắng = số buổi dự kiến x ngưỡng (mặc định 20%).
    private int AllowedAbsences(int plannedSessions) => (int)Math.Floor(plannedSessions * Threshold);

    // Admin xem tất cả, giảng viên xem lớp mình dạy, sinh viên xem lớp đã đăng ký.
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var q = classes.Classes().AsQueryable();
        if (User.IsInRole(nameof(UserRole.GiangVien))) q = q.Where(c => c.TeacherId == CurrentUserId);
        else if (!IsAdmin) q = q.Where(c => c.Enrollments.Any(e => e.StudentId == CurrentUserId));

        var list = await q.OrderBy(c => c.Id)
            .Select(c => new
            {
                c.Id, c.Name, c.SubjectId, Subject = c.Subject.Name, c.TeacherId, Teacher = c.Teacher.FullName,
                c.Room, c.Schedule, c.PlannedSessions, StudentCount = c.Enrollments.Count()
            })
            .ToListAsync();
        return Ok(list);
    }

    // Thông tin chi tiết lớp. Sinh viên nhận thêm thống kê đi học của chính mình.
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetOne(int id)
    {
        var c = await classes.Classes()
            .Where(x => x.Id == id)
            .Select(x => new
            {
                x.Id, x.Name, x.SubjectId, Subject = x.Subject.Name, SubjectCode = x.Subject.Code,
                x.TeacherId, Teacher = x.Teacher.FullName, TeacherEmail = x.Teacher.Email,
                x.Room, x.Schedule, x.PlannedSessions, StudentCount = x.Enrollments.Count()
            })
            .FirstOrDefaultAsync();
        if (c is null) return NotFound(NoAccess);

        var canManage = IsAdmin || c.TeacherId == CurrentUserId;
        var enrolled = !canManage && await classes.IsEnrolledAsync(id, CurrentUserId);
        if (!canManage && !enrolled) return NotFound(NoAccess);

        var now = DateTime.UtcNow;
        var sessionCount = await sessions.Sessions().CountAsync(s => s.ClassRoomId == id);
        var openCount = await sessions.Sessions()
            .CountAsync(s => s.ClassRoomId == id && s.IsOpen && (s.EndsAt == null || s.EndsAt > now));
        var myStats = enrolled
            ? (await BuildAbsenceReportAsync(id, c.PlannedSessions)).FirstOrDefault(r => r.StudentId == CurrentUserId)
            : null;

        return Ok(new
        {
            c.Id, c.Name, c.SubjectId, c.Subject, c.SubjectCode, c.TeacherId, c.Teacher, c.TeacherEmail,
            c.Room, c.Schedule, c.PlannedSessions, c.StudentCount,
            SessionCount = sessionCount,
            OpenSessionCount = openCount,
            AllowedAbsences = AllowedAbsences(c.PlannedSessions),
            CanManage = canManage,
            MyStats = myStats
        });
    }

    // Admin tạo lớp cho bất kỳ giảng viên nào; giảng viên tự tạo lớp cho chính mình.
    [HttpPost]
    [Authorize(Roles = TeacherOrAdmin)]
    public async Task<IActionResult> Create(ClassRequest req)
    {
        var teacherId = IsAdmin ? req.TeacherId : CurrentUserId;
        var error = await ValidateAsync(req, teacherId);
        if (error is not null) return BadRequest(error);

        var c = new ClassRoom
        {
            Name = req.Name.Trim(),
            SubjectId = req.SubjectId,
            TeacherId = teacherId,
            Room = Clean(req.Room),
            Schedule = Clean(req.Schedule),
            PlannedSessions = req.PlannedSessions
        };
        classes.AddClass(c);
        await classes.SaveAsync();
        return Ok(new { c.Id, c.Name, c.SubjectId, c.TeacherId, c.Room, c.Schedule, c.PlannedSessions });
    }

    // Giảng viên sửa được lớp của mình nhưng không đổi được giảng viên phụ trách.
    [HttpPut("{id:int}")]
    [Authorize(Roles = TeacherOrAdmin)]
    public async Task<IActionResult> Update(int id, ClassRequest req)
    {
        var c = await classes.FindManagedAsync(id, CurrentUserId, IsAdmin);
        if (c is null) return NotFound(NoAccess);

        var teacherId = IsAdmin ? req.TeacherId : c.TeacherId;
        var error = await ValidateAsync(req, teacherId);
        if (error is not null) return BadRequest(error);

        c.Name = req.Name.Trim();
        c.SubjectId = req.SubjectId;
        c.TeacherId = teacherId;
        c.Room = Clean(req.Room);
        c.Schedule = Clean(req.Schedule);
        c.PlannedSessions = req.PlannedSessions;
        await classes.SaveAsync();
        return Ok(new { c.Id, c.Name, c.SubjectId, c.TeacherId, c.Room, c.Schedule, c.PlannedSessions });
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = TeacherOrAdmin)]
    public async Task<IActionResult> Delete(int id)
    {
        var c = await classes.FindManagedAsync(id, CurrentUserId, IsAdmin);
        if (c is null) return NotFound(NoAccess);

        classes.RemoveClass(c);
        if (!await classes.SaveAsync()) return Conflict("Không thể xoá: lớp đang có buổi học hoặc sinh viên.");
        return NoContent();
    }

    [HttpGet("{id:int}/students")]
    public async Task<IActionResult> GetStudents(int id)
    {
        if (await classes.FindManagedAsync(id, CurrentUserId, IsAdmin) is null) return NotFound(NoAccess);

        var list = await classes.Enrollments().Where(e => e.ClassRoomId == id)
            .OrderBy(e => e.Student.FullName)
            .Select(e => new { e.StudentId, e.Student.Username, e.Student.FullName, e.Student.Email })
            .ToListAsync();
        return Ok(list);
    }

    // Sinh viên chưa có trong lớp, để giảng viên/admin chọn thêm vào lớp.
    [HttpGet("{id:int}/candidates")]
    public async Task<IActionResult> GetCandidates(int id, [FromQuery] string? q)
    {
        if (await classes.FindManagedAsync(id, CurrentUserId, IsAdmin) is null) return NotFound(NoAccess);

        var query = users.Users().Where(u =>
            u.Role == UserRole.SinhVien && u.IsActive &&
            !classes.Enrollments().Any(e => e.ClassRoomId == id && e.StudentId == u.Id));
        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            query = query.Where(u => u.FullName.Contains(term) || u.Username.Contains(term) || u.Email.Contains(term));
        }
        var list = await query.OrderBy(u => u.FullName).Take(50)
            .Select(u => new { u.Id, u.Username, u.FullName, u.Email })
            .ToListAsync();
        return Ok(list);
    }

    [HttpPost("{id:int}/students")]
    public async Task<IActionResult> Enroll(int id, EnrollRequest req)
    {
        if (await classes.FindManagedAsync(id, CurrentUserId, IsAdmin) is null) return NotFound(NoAccess);
        if (!await users.Users().AnyAsync(u => u.Id == req.StudentId && u.Role == UserRole.SinhVien))
            return BadRequest("Sinh viên không hợp lệ.");

        classes.AddEnrollment(new Enrollment { ClassRoomId = id, StudentId = req.StudentId });
        if (!await classes.SaveAsync()) return Conflict("Sinh viên đã có trong lớp.");
        return Ok(new { message = "Đã thêm sinh viên vào lớp." });
    }

    [HttpDelete("{id:int}/students/{studentId:int}")]
    public async Task<IActionResult> Unenroll(int id, int studentId)
    {
        if (await classes.FindManagedAsync(id, CurrentUserId, IsAdmin) is null) return NotFound(NoAccess);
        var e = await classes.Enrollments().FirstOrDefaultAsync(x => x.ClassRoomId == id && x.StudentId == studentId);
        if (e is null) return NotFound();

        classes.RemoveEnrollment(e);
        await classes.SaveAsync();
        return NoContent();
    }

    // Báo cáo vắng: chỉ tính buổi đã kết thúc. Vắng = không điểm danh và không có đơn nghỉ được duyệt.
    [HttpGet("{id:int}/absence-report")]
    public async Task<IActionResult> AbsenceReport(int id)
    {
        var c = await classes.FindManagedAsync(id, CurrentUserId, IsAdmin);
        if (c is null) return NotFound(NoAccess);
        return Ok(await BuildAbsenceReportAsync(id, c.PlannedSessions));
    }

    [HttpPost("{id:int}/send-warnings")]
    public async Task<IActionResult> SendWarnings(int id)
    {
        var c = await classes.FindManagedAsync(id, CurrentUserId, IsAdmin);
        if (c is null) return NotFound(NoAccess);

        var subject = await classes.Subjects().FirstOrDefaultAsync(s => s.Id == c.SubjectId);
        var warned = (await BuildAbsenceReportAsync(id, c.PlannedSessions)).Where(r => r.IsWarned).ToList();
        foreach (var r in warned)
        {
            var remaining = r.RemainingAbsences > 0
                ? $"Bạn chỉ còn được nghỉ tối đa {r.RemainingAbsences} buổi."
                : "Bạn đã nghỉ vượt số buổi cho phép.";
            await email.SendAsync(
                r.Email,
                $"Cảnh báo vắng học - {c.Name}",
                $"Bạn đã vắng {r.AbsentSessions}/{r.TotalSessions} buổi của lớp {c.Name} ({subject?.Name}). {remaining} Vui lòng liên hệ giảng viên.");
        }
        return Ok(new { sent = warned.Count });
    }

    private async Task<string?> ValidateAsync(ClassRequest req, int teacherId)
    {
        if (string.IsNullOrWhiteSpace(req.Name)) return "Vui lòng nhập tên lớp.";
        if (req.PlannedSessions is < 1 or > 100) return "Số buổi dự kiến phải từ 1 đến 100.";
        if (!await classes.Subjects().AnyAsync(s => s.Id == req.SubjectId)) return "Môn học không tồn tại.";
        if (!await users.Users().AnyAsync(u => u.Id == teacherId && u.Role == UserRole.GiangVien))
            return "Giảng viên không hợp lệ.";
        return null;
    }

    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private async Task<List<AbsenceRow>> BuildAbsenceReportAsync(int classId, int plannedSessions)
    {
        var now = DateTime.UtcNow;
        var allowed = AllowedAbsences(plannedSessions);

        var sessionIds = await sessions.Sessions()
            .Where(s => s.ClassRoomId == classId && (!s.IsOpen || (s.EndsAt != null && s.EndsAt <= now)))
            .Select(s => s.Id)
            .ToListAsync();
        var students = await classes.Enrollments().Where(e => e.ClassRoomId == classId)
            .Select(e => new { e.StudentId, e.Student.Username, e.Student.FullName, e.Student.Email })
            .ToListAsync();
        var present = (await sessions.Attendances().Where(a => sessionIds.Contains(a.ClassSessionId))
                .Select(a => new { a.ClassSessionId, a.StudentId })
                .ToListAsync())
            .Select(x => (x.ClassSessionId, x.StudentId))
            .ToHashSet();
        var excused = (await leaves.LeaveRequests()
                .Where(l => sessionIds.Contains(l.ClassSessionId) && l.Status == LeaveStatus.Approved)
                .Select(l => new { l.ClassSessionId, l.StudentId })
                .ToListAsync())
            .Select(x => (x.ClassSessionId, x.StudentId))
            .ToHashSet();

        var total = sessionIds.Count;
        return students.Select(s =>
        {
            var presentCount = sessionIds.Count(sid => present.Contains((sid, s.StudentId)));
            var excusedCount = sessionIds.Count(sid => !present.Contains((sid, s.StudentId)) && excused.Contains((sid, s.StudentId)));
            var absent = total - presentCount - excusedCount;
            var rate = total == 0 ? 0 : (double)absent / total;
            var remaining = allowed - absent;
            // Cảnh báo sớm: còn từ 1 buổi được nghỉ trở xuống thì cảnh báo, không đợi tới khi vượt.
            return new AbsenceRow(
                s.StudentId, s.Username, s.FullName, s.Email,
                total, presentCount, excusedCount, absent, rate, remaining,
                absent > 0 && remaining <= 1);
        }).ToList();
    }
}
