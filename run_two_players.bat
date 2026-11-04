@echo off
cd /d "%~dp0"
set "GODOT=C:\Projects\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"

echo Starting Necromancer 1 (Host window)...
start "" "%GODOT%" --resolution 960x540 --position 40,60

ping -n 2 127.0.0.1 >nul

echo Starting Necromancer 2 (Client window)...
start "" "%GODOT%" --resolution 960x540 --position 1020,60 --client
