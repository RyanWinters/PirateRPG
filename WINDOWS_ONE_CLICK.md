# Windows one-click launcher

Build the Windows launcher executable locally at:

- `dist/RunPirateRPG.exe` (original location)
- `RunPirateRPG.exe` (repo root, easiest for double-clicking)

## Quick start (recommended)

1. Double-click `scripts\build_run_exe_here.bat`.
2. Double-click `scripts\setup_windows_showcase_save.bat` (optional, seeds a playable showcase state).
3. Double-click `RunPirateRPG.exe` from the repository root.

## How it works

1. On first run, `RunPirateRPG.exe` downloads the official Godot 4.2.2 Windows executable.
2. It stores Godot at `tools/godot/Godot_v4.2.2-stable_win64.exe`.
3. It launches the current project (`project.godot`) so you can test the latest game state.
4. Launcher location supported: repository root **or** `dist/`.

## Rebuild launcher

From WSL/Linux/macOS:

```bash
./scripts/build_windows_launcher.sh
```

From Windows (Command Prompt):

```bat
scripts\build_windows_launcher.bat
```

To create a root-level executable for one-click play:

```bat
scripts\build_run_exe_here.bat
```

## Important for GitHub

Do **not** commit `RunPirateRPG.exe`, `dist/RunPirateRPG.exe`, or any other binaries.

After you push source changes, generate EXEs locally with one of:

```bash
./scripts/build_windows_launcher.sh
```

```bat
scripts\build_windows_launcher.bat
scripts\build_run_exe_here.bat
```

Then share built executables outside git (for example: GitHub Release asset, cloud drive, or chat upload).
