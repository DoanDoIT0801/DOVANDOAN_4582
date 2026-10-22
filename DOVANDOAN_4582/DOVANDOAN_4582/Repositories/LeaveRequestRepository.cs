using DOVANDOAN_4582.model;

namespace DOVANDOAN_4582.Repositories;

public class LeaveRequestRepository(ApplicationDbContext db) : ILeaveRequestRepository
{
    public IQueryable<LeaveRequest> LeaveRequests() => db.LeaveRequests;

    public void Add(LeaveRequest leaveRequest) => db.LeaveRequests.Add(leaveRequest);

    public Task<bool> SaveAsync() => db.TrySaveAsync();
}
