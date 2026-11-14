using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RentMate.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddItemLocation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Area",
                table: "Items",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Province",
                table: "Items",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Items_Province",
                table: "Items",
                column: "Province");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Items_Province",
                table: "Items");

            migrationBuilder.DropColumn(
                name: "Area",
                table: "Items");

            migrationBuilder.DropColumn(
                name: "Province",
                table: "Items");
        }
    }
}
