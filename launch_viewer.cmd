@echo off
setlocal
if not defined GODOT_BIN set "GODOT_BIN=godot"
if not exist "%~dp0runtime" mkdir "%~dp0runtime"
set "APPDATA=%~dp0runtime"
start /wait "" "%GODOT_BIN%" --headless --editor --path "%~dp0godot" --import --log-file "%~dp0runtime\import.log"
if errorlevel 1 (
  echo Set GODOT_BIN to the full path of your Godot executable, then try again.
  pause
  exit /b 1
)
start "" "%GODOT_BIN%" --path "%~dp0godot" --log-file "%~dp0runtime\viewer.log"
