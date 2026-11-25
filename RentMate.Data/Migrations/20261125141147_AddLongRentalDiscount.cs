using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RentMate.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddLongRentalDiscount : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "DiscountAmount",
                table: "Rentals",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "DiscountPercent",
                table: "Rentals",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "DiscountMinDays",
                table: "Items",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "DiscountPercent",
                table: "Items",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DiscountAmount",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "DiscountPercent",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "DiscountMinDays",
                table: "Items");

            migrationBuilder.DropColumn(
                name: "DiscountPercent",
                table: "Items");
        }
    }
}
