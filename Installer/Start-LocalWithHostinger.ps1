$ErrorActionPreference = "Stop"

$hostName = "srv1956950.hstgr.cloud"
$projectPath = Join-Path $PSScriptRoot "..\InfiniteCoffee2\InfiniteCoffee2.csproj"

if (-not (Get-Command ssh.exe -ErrorAction SilentlyContinue)) {
    throw "OpenSSH nao foi encontrado no Windows."
}

Write-Host "Abrindo tunel para o SQL Server da Hostinger..."
$tunnelCommand = "ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=60 -N -L 11433:127.0.0.1:1433 root@$hostName"
$tunnel = Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile", "-NoExit", "-Command", $tunnelCommand
) -PassThru

try {
    Start-Sleep -Seconds 2
    if ($tunnel.HasExited) {
        throw "O tunel SSH nao iniciou."
    }

    Write-Host "Buscando a configuracao do banco no servidor..."
    $line = (& ssh.exe "root@$hostName" "grep '^PADARIA_CONNECTION_STRING=' /opt/padaria-api/app.env").Trim()
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "A configuracao PADARIA_CONNECTION_STRING nao foi encontrada no servidor."
    }

    $connection = $line -replace '^PADARIA_CONNECTION_STRING=', ''
    $connection = $connection.Trim().Trim([char]39, [char]34)
    $connection = $connection -replace 'Server=localhost,1433', 'Server=127.0.0.1,11433'
    $connection = $connection -replace 'Encrypt=True', 'Encrypt=False'
    $env:PADARIA_CONNECTION_STRING = $connection

    Write-Host "Iniciando o MVC em http://localhost:5049 ..."
    dotnet run --project $projectPath -- --urls=http://localhost:5049
}
finally {
    if ($tunnel -and -not $tunnel.HasExited) {
        taskkill.exe /PID $tunnel.Id /T /F | Out-Null
    }
}
