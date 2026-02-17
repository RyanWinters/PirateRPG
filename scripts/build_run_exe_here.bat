@echo off
setlocal enabledelayedexpansion

REM Builds RunPirateRPG.exe directly into repository root.

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"
set "OUTPUT_EXE=%ROOT_DIR%\RunPirateRPG.exe"

where go >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Go is not installed or not available in PATH.
  echo         Install Go from https://go.dev/dl/ and try again.
  exit /b 1
)

pushd "%ROOT_DIR%" >nul
if errorlevel 1 (
  echo [ERROR] Failed to enter repository root: "%ROOT_DIR%"
  exit /b 1
)

set "CGO_ENABLED=0"
set "GOOS=windows"
set "GOARCH=amd64"

go build -ldflags="-s -w -H=windowsgui" -o "%OUTPUT_EXE%" .\tools\launcher\main.go
if errorlevel 1 (
  echo [ERROR] Build failed.
  popd >nul
  exit /b 1
)

popd >nul

echo [OK] Built "%OUTPUT_EXE%"
exit /b 0
