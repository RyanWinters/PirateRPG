# Windows one-click launcher

Build the Windows launcher executable locally at:

- `dist/RunPirateRPG.exe`

## How it works

1. Double-click `RunPirateRPG.exe` from the **root** of this repository.
2. On first run, it downloads the official Godot 4.2.2 Windows executable.
3. It stores Godot at `tools/godot/Godot_v4.2.2-stable_win64.exe`.
4. It launches the current project (`project.godot`) so you can test the latest game state.

## Rebuild launcher

From WSL/Linux/macOS:

```bash
./scripts/build_windows_launcher.sh
```

From Windows (Command Prompt):

```bat
scripts\build_windows_launcher.bat
```

You can also double-click `scripts\build_windows_launcher.bat` in File Explorer.

## Important for GitHub

Do **not** commit `dist/RunPirateRPG.exe` (or any other binaries).

After you push the source changes, generate the EXE locally with one of:

```bash
./scripts/build_windows_launcher.sh
```

```bat
scripts\build_windows_launcher.bat
```

Then share the built executable outside git (for example: GitHub Release asset, cloud drive, or chat upload).
