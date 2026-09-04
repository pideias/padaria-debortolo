using System.Text;
using System.Text.Json;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Drive.v3;
using Google.Apis.Services;
using InfiniteCoffee2.Data;

namespace InfiniteCoffee2.Services;

/// <summary>
/// Publica snapshots no Google Drive pela API. O SQL Server continua sendo a fonte
/// oficial; o Google Drive armazena apenas cópias de consulta.
/// </summary>
public sealed class GoogleDriveSnapshotHostedService : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(30);
    private readonly ILogger<GoogleDriveSnapshotHostedService> _logger;
    private readonly string? _serviceAccountJson;
    private readonly string? _folderId;
    private readonly string _fileName;

    public GoogleDriveSnapshotHostedService(ILogger<GoogleDriveSnapshotHostedService> logger)
    {
        _logger = logger;
        _serviceAccountJson = Environment.GetEnvironmentVariable("GOOGLE_DRIVE_SERVICE_ACCOUNT_JSON");
        _folderId = Environment.GetEnvironmentVariable("GOOGLE_DRIVE_FOLDER_ID");
        _fileName = Environment.GetEnvironmentVariable("GOOGLE_DRIVE_SNAPSHOT_NAME") ?? "estoque.json";
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (string.Equals(Environment.GetEnvironmentVariable("PADARIA_SNAPSHOT_ONLY"), "true", StringComparison.OrdinalIgnoreCase))
            return;

        if (string.IsNullOrWhiteSpace(_serviceAccountJson) || string.IsNullOrWhiteSpace(_folderId))
        {
            _logger.LogInformation("Upload Google Drive desativado: configure GOOGLE_DRIVE_SERVICE_ACCOUNT_JSON e GOOGLE_DRIVE_FOLDER_ID.");
            return;
        }

        await UploadSnapshotAsync(stoppingToken);
        using var timer = new PeriodicTimer(Interval);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            await UploadSnapshotAsync(stoppingToken);
        }
    }

    public async Task<bool> PublicarAgoraAsync(CancellationToken cancellationToken = default)
    {
        if (string.Equals(Environment.GetEnvironmentVariable("PADARIA_SNAPSHOT_ONLY"), "true", StringComparison.OrdinalIgnoreCase) ||
            string.IsNullOrWhiteSpace(_serviceAccountJson) || string.IsNullOrWhiteSpace(_folderId))
            return false;
        return await UploadSnapshotAsync(cancellationToken);
    }

    private async Task<bool> UploadSnapshotAsync(CancellationToken cancellationToken)
    {
        try
        {
            var credential = GoogleCredential
                .FromJson(_serviceAccountJson!)
                .CreateScoped(DriveService.Scope.Drive);
            using var drive = new DriveService(new BaseClientService.Initializer
            {
                HttpClientInitializer = credential,
                ApplicationName = "Padaria Debortolo"
            });

            var snapshot = new
            {
                versao = Banco.ObterVersaoEstoque(),
                atualizadoEm = DateTime.UtcNow,
                produtos = Banco.ListarEstoque()
            };
            var json = JsonSerializer.Serialize(snapshot);
            await using var content = new MemoryStream(Encoding.UTF8.GetBytes(json));
            var existing = await FindSnapshotAsync(drive, cancellationToken);
            var metadata = new Google.Apis.Drive.v3.Data.File
            {
                Name = _fileName,
                Parents = existing is null ? new List<string> { _folderId! } : null,
                MimeType = "application/json"
            };

            Google.Apis.Upload.IUploadProgress result;
            if (existing is null)
            {
                var request = drive.Files.Create(metadata, content, "application/json");
                request.Fields = "id, name, modifiedTime";
                result = await request.UploadAsync(cancellationToken);
            }
            else
            {
                var request = drive.Files.Update(metadata, existing.Id, content, "application/json");
                request.Fields = "id, name, modifiedTime";
                result = await request.UploadAsync(cancellationToken);
            }

            if (result.Status != Google.Apis.Upload.UploadStatus.Completed)
                throw result.Exception ?? new InvalidOperationException("Upload do snapshot não foi concluído.");

            await UploadJsonAsync(
                drive,
                "vendas.json",
                JsonSerializer.Serialize(new
                {
                    atualizadoEm = DateTime.UtcNow,
                    vendas = Banco.HistoricoVendas()
                }),
                cancellationToken);

            _logger.LogInformation("Snapshot do estoque enviado ao Google Drive em {Time}.", DateTimeOffset.Now);
            return true;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return false;
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Não foi possível enviar o snapshot do estoque ao Google Drive.");
            return false;
        }
    }

    private async Task<Google.Apis.Drive.v3.Data.File?> FindSnapshotAsync(
        DriveService drive,
        CancellationToken cancellationToken)
    {
        return await FindFileAsync(drive, _fileName, cancellationToken);
    }

    private async Task<Google.Apis.Drive.v3.Data.File?> FindFileAsync(
        DriveService drive, string name, CancellationToken cancellationToken)
    {
        var request = drive.Files.List();
        request.Q = $"'{_folderId}' in parents and name = '{name.Replace("'", "\\'")}' and trashed = false";
        request.Fields = "files(id, name)";
        request.PageSize = 10;
        var result = await request.ExecuteAsync(cancellationToken);
        return result.Files.FirstOrDefault();
    }

    private async Task UploadJsonAsync(DriveService drive, string name, string json, CancellationToken cancellationToken)
    {
        await using var content = new MemoryStream(Encoding.UTF8.GetBytes(json));
        var existing = await FindFileAsync(drive, name, cancellationToken);
        var metadata = new Google.Apis.Drive.v3.Data.File
        {
            Name = name,
            Parents = existing is null ? new List<string> { _folderId! } : null,
            MimeType = "application/json"
        };
        Google.Apis.Upload.IUploadProgress result = existing is null
            ? await drive.Files.Create(metadata, content, "application/json").UploadAsync(cancellationToken)
            : await drive.Files.Update(metadata, existing.Id, content, "application/json").UploadAsync(cancellationToken);
        if (result.Status != Google.Apis.Upload.UploadStatus.Completed)
            throw result.Exception ?? new InvalidOperationException($"Upload de {name} não foi concluído.");
    }
}
