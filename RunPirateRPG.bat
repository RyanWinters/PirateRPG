@echo off
setlocal

set "ROOT=%~dp0"
set "PS_SCRIPT=%ROOT%scripts\run_piraterpg_win11.ps1"

if not exist "%PS_SCRIPT%" (
  echo Missing launcher script: %PS_SCRIPT%
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
if errorlevel 1 (
  echo.
  echo Launcher failed. See error above.
  pause
  exit /b 1
)

endlocal
