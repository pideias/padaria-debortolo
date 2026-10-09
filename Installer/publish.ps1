[CmdletBinding()]
param(
    [switch]$SkipFlutter,
    [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$artifacts = Join-Path $root 'artifacts'
$serverOutput = Join-Path $artifacts 'server'
$desktopOutput = Join-Path $artifacts 'desktop'

Remove-Item -LiteralPath $artifacts -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $artifacts | Out-Null
New-Item -ItemType Directory -Path $serverOutput, $desktopOutput | Out-Null

Write-Host 'Publicando backend ASP.NET Core self-contained...'
dotnet publish (Join-Path $root 'InfiniteCoffee2\InfiniteCoffee2.csproj') `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    --output $serverOutput

if (-not $SkipFlutter) {
    Write-Host 'Gerando aplicativo Flutter Desktop...'
    Push-Location (Join-Path $root 'InfiniteCoffeeMobile')
    try {
        flutter build windows --release
    }
    finally {
        Pop-Location
    }

    $flutterOutput = Join-Path $root 'InfiniteCoffeeMobile\build\windows\x64\runner\Release'
    Copy-Item -Path (Join-Path $flutterOutput '*') -Destination $desktopOutput -Recurse -Force
}

Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Start-PadariaDebortolo.cmd') -Destination $serverOutput -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Start-PadariaDesktop.cmd') -Destination $artifacts -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Start-PadariaDesktop.ps1') -Destination $artifacts -Force

if (-not $SkipInstaller) {
    $isccCandidates = @(
        (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source,
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 7\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if ($isccCandidates.Count -eq 0) {
        Write-Warning 'Inno Setup nao encontrado. Os artefatos foram gerados, mas o .exe instalador nao foi compilado.'
        Write-Warning 'Instale o Inno Setup 7 ou 6 e execute este script novamente.'
    }
    else {
        Write-Host 'Compilando instalador Windows...'
        $issFile = Join-Path $PSScriptRoot 'PadariaDebortolo.iss'
        $isccPath = @($isccCandidates)[0]
        $process = Start-Process -FilePath $isccPath -ArgumentList "`"$issFile`"" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {
            throw "O Inno Setup falhou com o codigo $($process.ExitCode)."
        }
    }
}

Write-Host "Artefatos gerados em $artifacts"
