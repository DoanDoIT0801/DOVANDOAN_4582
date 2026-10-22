using DOVANDOAN_4582.model;

namespace DOVANDOAN_4582.Repositories;

public interface ILeaveRequestRepository
{
    IQueryable<LeaveRequest> LeaveRequests();
    void Add(LeaveRequest leaveRequest);
    Task<bool> SaveAsync();
}
