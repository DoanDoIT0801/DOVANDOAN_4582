using DOVANDOAN_4582.model;

namespace DOVANDOAN_4582.Repositories;

public interface IClassRepository
{
    IQueryable<Subject> Subjects();
    IQueryable<ClassRoom> Classes();
    IQueryable<Enrollment> Enrollments();
    Task<ClassRoom?> FindManagedAsync(int classId, int userId, bool isAdmin);
    Task<bool> IsEnrolledAsync(int classId, int studentId);
    void AddSubject(Subject subject);
    void RemoveSubject(Subject subject);
    void AddClass(ClassRoom classRoom);
    void RemoveClass(ClassRoom classRoom);
    void AddEnrollment(Enrollment enrollment);
    void RemoveEnrollment(Enrollment enrollment);
    Task<bool> SaveAsync();
}
