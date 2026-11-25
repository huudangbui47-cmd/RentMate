using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RentMate.Data.Migrations
{
    /// <inheritdoc />
    public partial class TextResourceKeyCaseSensitive : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Key",
                table: "TextResources",
                type: "nvarchar(450)",
                maxLength: 450,
                nullable: false,
                collation: "Latin1_General_100_CS_AS",
                oldClrType: typeof(string),
                oldType: "nvarchar(450)",
                oldMaxLength: 450);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Key",
                table: "TextResources",
                type: "nvarchar(450)",
                maxLength: 450,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(450)",
                oldMaxLength: 450,
                oldCollation: "Latin1_General_100_CS_AS");
        }
    }
}
