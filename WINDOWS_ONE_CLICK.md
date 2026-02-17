# Windows 11 one-click launcher

Use this on Windows 11:

- Double-click `RunPirateRPG.bat` from the repo root.

## What happens

1. `RunPirateRPG.bat` runs `scripts/run_piraterpg_win11.ps1`.
2. If needed, it downloads the official Godot 4.2.2 Windows runtime.
3. It extracts Godot to `tools/godot/Godot_v4.2.2-stable_win64.exe`.
4. It launches this project (`project.godot`) immediately.

## Important for GitHub

Do **not** commit `dist/RunPirateRPG.exe` (or any other binary artifacts).

If you still want a standalone EXE launcher, you can build it locally with:

```bash
./scripts/build_windows_launcher.sh
```

…and share that EXE outside git (for example as a GitHub Release asset).
