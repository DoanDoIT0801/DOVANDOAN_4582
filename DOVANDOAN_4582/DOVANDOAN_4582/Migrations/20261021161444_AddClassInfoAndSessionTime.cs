using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DOVANDOAN_4582.Migrations
{
    /// <inheritdoc />
    public partial class AddClassInfoAndSessionTime : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "EndsAt",
                table: "ClassSessions",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PlannedSessions",
                table: "ClassRooms",
                type: "int",
                nullable: false,
                defaultValue: 15);

            migrationBuilder.AddColumn<string>(
                name: "Room",
                table: "ClassRooms",
                type: "nvarchar(255)",
                maxLength: 255,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Schedule",
                table: "ClassRooms",
                type: "nvarchar(255)",
                maxLength: 255,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsManual",
                table: "Attendances",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "EndsAt",
                table: "ClassSessions");

            migrationBuilder.DropColumn(
                name: "PlannedSessions",
                table: "ClassRooms");

            migrationBuilder.DropColumn(
                name: "Room",
                table: "ClassRooms");

            migrationBuilder.DropColumn(
                name: "Schedule",
                table: "ClassRooms");

            migrationBuilder.DropColumn(
                name: "IsManual",
                table: "Attendances");
        }
    }
}
