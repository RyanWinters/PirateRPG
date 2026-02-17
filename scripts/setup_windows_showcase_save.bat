@echo off
setlocal enabledelayedexpansion

REM Seeds a showcase save so first launch has crew, resources, and expedition options visible.

set "APPDATA_DIR=%APPDATA%"
if "%APPDATA_DIR%"=="" (
  echo [ERROR] APPDATA is not defined. Run this from Windows.
  exit /b 1
)

set "SAVE_DIR=%APPDATA_DIR%\Godot\app_userdata\PirateRPG"
set "SAVE_FILE=%SAVE_DIR%\savegame.json"

if not exist "%SAVE_DIR%" mkdir "%SAVE_DIR%"
if errorlevel 1 (
  echo [ERROR] Failed to create save directory: "%SAVE_DIR%"
  exit /b 1
)

(
  echo {
  echo   "save_version": 1,
  echo   "resources": {
  echo     "gold": 900,
  echo     "food": 60
  echo   },
  echo   "crew_roster": [
  echo     {"id":"crew_riggs","name":"Riggs","combat":52,"stealth":41,"loyalty":72,"upkeep":2,"assignment":""},
  echo     {"id":"crew_ivy","name":"Ivy","combat":36,"stealth":58,"loyalty":68,"upkeep":2,"assignment":""},
  echo     {"id":"crew_salt","name":"Old Salt","combat":49,"stealth":33,"loyalty":77,"upkeep":3,"assignment":""},
  echo     {"id":"crew_nyx","name":"Nyx","combat":44,"stealth":63,"loyalty":61,"upkeep":2,"assignment":""}
  echo   ],
  echo   "current_phase": 2,
  echo   "last_save_unix": 0,
  echo   "last_active_unix": 0,
  echo   "last_steal_click_msec": -225,
  echo   "passive_tick_accumulator": 0.0,
  echo   "pickpocket_level": 4,
  echo   "pickpocket_xp": 180,
  echo   "unlocked_upgrades": ["quick_hands","crowd_reader","lock_tumbler"],
  echo   "crew_slots_unlocked": 1,
  echo   "expedition_runtime": {
  echo     "runtime_counter": 0,
  echo     "active_expeditions": {}
  echo   }
  echo }
) > "%SAVE_FILE%"

if errorlevel 1 (
  echo [ERROR] Failed to write showcase save file.
  exit /b 1
)

echo [OK] Wrote showcase save: "%SAVE_FILE%"
exit /b 0
