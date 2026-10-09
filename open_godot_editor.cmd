@echo off
setlocal
if not defined GODOT_BIN set "GODOT_BIN=godot"
if not exist "%~dp0runtime" mkdir "%~dp0runtime"
set "APPDATA=%~dp0runtime"
start "" "%GODOT_BIN%" --editor --path "%~dp0godot" --log-file "%~dp0runtime\editor.log"
if errorlevel 1 (
  echo Set GODOT_BIN to the full path of your Godot executable, then try again.
  pause
)
