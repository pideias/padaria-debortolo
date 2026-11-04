@echo off
setlocal
set "APP_DIR=%~dp0"
set "SERVER=%APP_DIR%InfiniteCoffee2.exe"
set "URL=http://localhost:5049"

if not exist "%SERVER%" (
  echo Backend nao encontrado em "%SERVER%".
  pause
  exit /b 1
)

start "Infinite Coffee - API" /min "%SERVER%" --urls "%URL%"
timeout /t 2 /nobreak >nul
start "" "%URL%"
endlocal
