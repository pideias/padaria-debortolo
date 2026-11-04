@echo off
setlocal
set "APP_DIR=%~dp0"
start "Infinite Coffee" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%APP_DIR%Start-InfiniteCoffeeDesktop.ps1"
endlocal
