using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RentMate.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddDamageClaimAndAiReport : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "DamageAmount",
                table: "Rentals",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateTime>(
                name: "DamageClaimedAt",
                table: "Rentals",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DamageNote",
                table: "Rentals",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DisputeReason",
                table: "Rentals",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DisputedAt",
                table: "Rentals",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ResolutionNote",
                table: "Rentals",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "AiAnalyzedAt",
                table: "ConditionReports",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AiDamages",
                table: "ConditionReports",
                type: "nvarchar(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "AiNewDamageFound",
                table: "ConditionReports",
                type: "bit",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "AiSuggestedCondition",
                table: "ConditionReports",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "AiSuggestedDeduction",
                table: "ConditionReports",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AiSummary",
                table: "ConditionReports",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DamageAmount",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "DamageClaimedAt",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "DamageNote",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "DisputeReason",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "DisputedAt",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "ResolutionNote",
                table: "Rentals");

            migrationBuilder.DropColumn(
                name: "AiAnalyzedAt",
                table: "ConditionReports");

            migrationBuilder.DropColumn(
                name: "AiDamages",
                table: "ConditionReports");

            migrationBuilder.DropColumn(
                name: "AiNewDamageFound",
                table: "ConditionReports");

            migrationBuilder.DropColumn(
                name: "AiSuggestedCondition",
                table: "ConditionReports");

            migrationBuilder.DropColumn(
                name: "AiSuggestedDeduction",
                table: "ConditionReports");

            migrationBuilder.DropColumn(
                name: "AiSummary",
                table: "ConditionReports");
        }
    }
}
