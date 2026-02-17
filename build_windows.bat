@echo off
setlocal

REM Usage:
REM   build_windows.bat [path_to_godot_console_exe]
REM Example:
REM   build_windows.bat "C:\Tools\Godot_v4.2.2-stable_win64_console.exe"

set GODOT_EXE=%~1
if "%GODOT_EXE%"=="" set GODOT_EXE=godot

if not exist build mkdir build

echo Building Windows export with: %GODOT_EXE%
"%GODOT_EXE%" --headless --path . --export-release "Windows Desktop" "build/NeonTideSurvivors.exe"
if errorlevel 1 (
  echo.
  echo Build failed. Make sure:
  echo 1) Godot 4.x is installed.
  echo 2) Export templates are installed in Godot.
  echo 3) export_presets.cfg exists.
  exit /b 1
)

echo.
echo Build complete: build\NeonTideSurvivors.exe
endlocal
