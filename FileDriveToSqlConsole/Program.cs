using System.Text;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

var configuration = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: false)
    .Build();

var settings = configuration.GetSection("ImportSettings").Get<ImportSettings>()
    ?? throw new InvalidOperationException("ImportSettings is missing in appsettings.json.");

if (!Directory.Exists(settings.SourceFolderPath))
{
    Console.WriteLine($"Source folder not found: {settings.SourceFolderPath}");
    return;
}

var files = Directory.GetFiles(settings.SourceFolderPath, settings.SearchPattern, SearchOption.TopDirectoryOnly);

if (files.Length == 0)
{
    Console.WriteLine("No files found to import.");
    return;
}

await using var connection = new SqlConnection(settings.SqlConnectionString);
await connection.OpenAsync();

foreach (var filePath in files)
{
    var fileName = Path.GetFileName(filePath);
    var content = await File.ReadAllTextAsync(filePath, Encoding.UTF8);

    const string sql = """
        INSERT INTO dbo.Documents (FileName, FilePath, Content, ImportedOnUtc)
        VALUES (@FileName, @FilePath, @Content, SYSUTCDATETIME());
        """;

    await using var command = new SqlCommand(sql, connection);
    command.Parameters.AddWithValue("@FileName", fileName);
    command.Parameters.AddWithValue("@FilePath", filePath);
    command.Parameters.AddWithValue("@Content", content);

    await command.ExecuteNonQueryAsync();
    Console.WriteLine($"Imported: {fileName}");
}

Console.WriteLine($"Done. Imported {files.Length} file(s).");

public sealed class ImportSettings
{
    public string SourceFolderPath { get; init; } = string.Empty;
    public string SearchPattern { get; init; } = "*.txt";
    public string SqlConnectionString { get; init; } = string.Empty;
}
