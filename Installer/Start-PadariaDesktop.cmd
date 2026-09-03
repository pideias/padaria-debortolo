@echo off
setlocal
set "APP_DIR=%~dp0"
start "Padaria Debortolo" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%APP_DIR%Start-PadariaDesktop.ps1"
endlocal
