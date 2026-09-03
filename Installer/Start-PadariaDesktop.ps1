[CmdletBinding()]
param(
    [string]$CredentialsPath = '',
    [string]$FolderId = '1yP55ALmQDCwhhhaLQ5SJkGrWF0mewGPa'
)

$ErrorActionPreference = 'Stop'
$appDir = Split-Path -Parent $PSScriptRoot
$server = Join-Path $appDir 'server\InfiniteCoffee2.exe'
$desktop = Join-Path $appDir 'desktop\infinite_coffee_app.exe'

if (-not (Test-Path -LiteralPath $server)) {
    throw "Backend nao encontrado em '$server'."
}
if (-not (Test-Path -LiteralPath $desktop)) {
    throw "Aplicativo desktop nao encontrado em '$desktop'."
}

if ([string]::IsNullOrWhiteSpace($CredentialsPath)) {
    $knownPaths = @(
        (Join-Path $env:USERPROFILE 'Downloads\client_secret*.json'),
        'D:\client_secret*.json',
        (Join-Path $env:USERPROFILE 'client_secret*.json')
    )
    foreach ($pattern in $knownPaths) {
        $found = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'client_secret*.json' } |
            Select-Object -First 1
        if ($null -ne $found) {
            $CredentialsPath = $found.FullName
            break
        }
    }
}

$arguments = "--urls `"http://0.0.0.0:5049`""
if (-not [string]::IsNullOrWhiteSpace($CredentialsPath) -and
    (Test-Path -LiteralPath $CredentialsPath)) {
    $env:GOOGLE_DRIVE_OAUTH_CLIENT_PATH = (Resolve-Path -LiteralPath $CredentialsPath).Path
    $env:GOOGLE_DRIVE_FOLDER_ID = $FolderId
    $env:GOOGLE_DRIVE_SNAPSHOT_NAME = 'estoque.json'
}

Start-Process -FilePath $server -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $server) -WindowStyle Minimized
Start-Sleep -Seconds 3
Start-Process -FilePath $desktop -WorkingDirectory (Split-Path -Parent $desktop)
