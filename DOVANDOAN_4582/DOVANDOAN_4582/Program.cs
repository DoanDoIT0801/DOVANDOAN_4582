using System.Text;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using DOVANDOAN_4582.model;
using DOVANDOAN_4582.Repositories;
using DOVANDOAN_4582.Services;

// Nạp file .env nếu có
try
{
    DotNetEnv.Env.TraversePath().Load();
}
catch
{
    // Bỏ qua nếu không tìm thấy file .env
}

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;
var jwtKey = config["Jwt:Key"] ?? "DO_VAN_DOAN_4582_SUPER_SECRET_KEY_FOR_JWT_TOKEN_123456789";

builder.Services.AddDbContext<ApplicationDbContext>(o => o.UseSqlServer(config.GetConnectionString("Default")));
builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IClassRepository, ClassRepository>();
builder.Services.AddScoped<ISessionRepository, SessionRepository>();
builder.Services.AddScoped<ILeaveRequestRepository, LeaveRequestRepository>();

builder.Services.AddSingleton<PasswordHasher<AppUser>>();
builder.Services.AddScoped<JwtService>();
builder.Services.AddScoped<EmailService>();
builder.Services.AddScoped<FileStorageService>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
{
    o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = config["Jwt:Issuer"] ?? "DOVANDOAN_4582_API",
        ValidAudience = config["Jwt:Audience"] ?? "DOVANDOAN_4582_Mobile",
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
    };
});
builder.Services.AddAuthorization();

var app = builder.Build();

// Tạo/cập nhật database khi khởi động và tạo tài khoản admin đầu tiên.
try
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await db.Database.MigrateAsync();
    await DbSeeder.SeedAsync(db, config, scope.ServiceProvider.GetRequiredService<PasswordHasher<AppUser>>());
}
catch (Exception ex)
{
    Console.WriteLine($"DB Migration/Seeding Notice: {ex.Message}");
}

// Swagger bật khi Development hoặc khi Swagger:Enabled = true trong cấu hình.
if (app.Environment.IsDevelopment() || config.GetValue("Swagger:Enabled", true))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
