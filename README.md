# FileDrive to SQL Console App (.NET, VS Code)

This repository contains a .NET console application that reads document files from a folder (file drive) and inserts them into SQL Server.

## Project

- `FileDriveToSqlConsole/` – Console app source
- `FileDriveToSqlConsole/schema.sql` – SQL table script

## Prerequisites

1. Install **.NET 8 SDK**
2. Install **SQL Server** (local or remote)
3. Use **VS Code** with C# extension

## Setup

1. Create database/table:
   - Run `FileDriveToSqlConsole/schema.sql` against your SQL database.
2. Update config:
   - Edit `FileDriveToSqlConsole/appsettings.json`
   - Set:
     - `SourceFolderPath` to your file drive folder
     - `SearchPattern` (example: `*.txt`)
     - `SqlConnectionString`

## Run in VS Code terminal

```bash
cd FileDriveToSqlConsole
dotnet restore
dotnet run
```

## Notes

- This version reads each file as UTF-8 text and inserts into `dbo.Documents`.
- For binary documents (PDF/DOCX), change the table column type and app logic to store `VARBINARY(MAX)`.
