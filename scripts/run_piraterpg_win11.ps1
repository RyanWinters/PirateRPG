$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir '..')
$ProjectFile = Join-Path $ProjectRoot 'project.godot'

if (-not (Test-Path $ProjectFile)) {
    throw "project.godot not found at $ProjectFile. Keep RunPirateRPG.bat in the repository root."
}

$GodotVersion = '4.2.2'
$GodotZipUrl = 'https://github.com/godotengine/godot/releases/download/4.2.2-stable/Godot_v4.2.2-stable_win64.exe.zip'
$GodotDir = Join-Path $ProjectRoot 'tools\godot'
$GodotExe = Join-Path $GodotDir 'Godot_v4.2.2-stable_win64.exe'
$ZipPath = Join-Path $env:TEMP 'pirate-rpg-godot.zip'

if (-not (Test-Path $GodotExe)) {
    New-Item -Path $GodotDir -ItemType Directory -Force | Out-Null
    Write-Host "Godot $GodotVersion not found. Downloading runtime..."
    Invoke-WebRequest -Uri $GodotZipUrl -OutFile $ZipPath
    Expand-Archive -Path $ZipPath -DestinationPath $GodotDir -Force
    Remove-Item $ZipPath -ErrorAction SilentlyContinue
}

if (-not (Test-Path $GodotExe)) {
    throw "Godot executable was not found after extraction: $GodotExe"
}

Write-Host 'Launching PirateRPG...'
Start-Process -FilePath $GodotExe -WorkingDirectory $ProjectRoot -ArgumentList @('--path', $ProjectRoot)
