using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DOVANDOAN_4582.model;
using DOVANDOAN_4582.Repositories;

namespace DOVANDOAN_4582.Controllers;

[ApiController]
[Route("api/subjects")]
[Authorize]
public class SubjectsApiController(IClassRepository classes) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await classes.Subjects().OrderBy(s => s.Id).ToListAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetOne(int id)
    {
        var s = await classes.Subjects().FirstOrDefaultAsync(x => x.Id == id);
        return s is null ? NotFound() : Ok(s);
    }

    [HttpPost]
    [Authorize(Roles = nameof(UserRole.Admin))]
    public async Task<IActionResult> Create(SubjectRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Code) || string.IsNullOrWhiteSpace(req.Name))
            return BadRequest("Mã môn và tên môn không được để trống.");

        var code = req.Code.Trim().ToUpper();
        var name = req.Name.Trim();

        if (await classes.Subjects().AnyAsync(s => s.Code.ToUpper() == code))
            return Conflict($"Mã môn học '{code}' đã tồn tại.");

        var s = new Subject { Code = code, Name = name };
        classes.AddSubject(s);
        if (!await classes.SaveAsync()) return Conflict("Không thể lưu môn học.");
        return Ok(s);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = nameof(UserRole.Admin))]
    public async Task<IActionResult> Update(int id, SubjectRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Code) || string.IsNullOrWhiteSpace(req.Name))
            return BadRequest("Mã môn và tên môn không được để trống.");

        var s = await classes.Subjects().FirstOrDefaultAsync(x => x.Id == id);
        if (s is null) return NotFound();

        var code = req.Code.Trim().ToUpper();
        var name = req.Name.Trim();

        if (await classes.Subjects().AnyAsync(x => x.Id != id && x.Code.ToUpper() == code))
            return Conflict($"Mã môn học '{code}' đã tồn tại.");

        s.Code = code;
        s.Name = name;
        if (!await classes.SaveAsync()) return Conflict("Không thể cập nhật môn học.");
        return Ok(s);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = nameof(UserRole.Admin))]
    public async Task<IActionResult> Delete(int id)
    {
        var s = await classes.Subjects().FirstOrDefaultAsync(x => x.Id == id);
        if (s is null) return NotFound();

        var hasClasses = await classes.Classes().AnyAsync(c => c.SubjectId == id);
        if (hasClasses) return Conflict("Không thể xoá: môn học đang có lớp học sử dụng.");

        classes.RemoveSubject(s);
        if (!await classes.SaveAsync()) return Conflict("Không thể xoá môn học.");
        return NoContent();
    }
}
