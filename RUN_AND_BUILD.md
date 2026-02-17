# Neon Tide Survivors - Run & Build

## 1) Run locally in the editor
1. Install Godot 4.x (standard desktop editor build).
2. Open Godot and import this folder as a project.
3. Press **F5** to run.

## 2) Run from command line (no editor UI)
If `godot` is on your PATH:

```bash
godot --path .
```

Or point directly to your Godot executable.

## 3) Build a Windows executable (no binaries committed)
Use the included batch script:

```bat
build_windows.bat "C:\path\to\Godot_v4.x-stable_win64_console.exe"
```

If Godot is already on PATH:

```bat
build_windows.bat
```

Output will be generated at:

- `build/NeonTideSurvivors.exe`

## Notes
- This repo intentionally does **not** include engine binaries or built executables.
- For export, install **Godot export templates** through the editor if prompted.
