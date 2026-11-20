using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RentMate.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddShippingVnPayRenterReport : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CancelReason",
                table: "Rentals",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "DeliveryMethod",
                table: "Rentals",
                type: "int",
                nullable: false,
                defaultValue: 1); // đơn cũ = gặp trực tiếp

            migrationBuilder.AddColumn<DateTime>(
                name: "ExpectedDeliveryAt",
                table: "Rentals",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "LateDeliveryRefund",
                table: "Rentals",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "ShiftedDays",
                table: "Rentals",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "ShipToAddress",
                table: "Rentals",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ShipToAreaText",
                table: "Rentals",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ShipToDistrictId",
                table: "Rentals",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ShipToName",
                table: "Rentals",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ShipToPhone",
                table: "Rentals",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ShipToWardCode",
                table: "Rentals",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ShippingCreatedAt",
                table: "Rentals",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ShippingFee",
                table: "Rentals",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ShippingOrderCode",
                table: "Rentals",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "AiSameItem",
                table: "ConditionReports",
                type: "bit",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CancelReason",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "DeliveryMethod",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ExpectedDeliveryAt",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "LateDeliveryRefund",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ShiftedDays",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ShipToAddress",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ShipToAreaText",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ShipToDistrictId",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ShipToName",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ShipToPhone",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ShipToWardCode",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ShippingCreatedAt",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ShippingFee",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ShippingOrderCode",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "AiSameItem",
                table: "ConditionReports");
        }
    }
}
