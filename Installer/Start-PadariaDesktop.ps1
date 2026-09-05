[CmdletBinding()]
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

$arguments = "--urls `"http://0.0.0.0:5049`""
Start-Process -FilePath $server -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $server) -WindowStyle Minimized
Start-Sleep -Seconds 3
Start-Process -FilePath $desktop -WorkingDirectory (Split-Path -Parent $desktop)
