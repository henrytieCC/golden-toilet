@echo off
setlocal
if not defined BLENDER_BIN set "BLENDER_BIN=blender"
start "" "%BLENDER_BIN%" "%~dp0golden_toilet.blend"
if errorlevel 1 (
  echo Set BLENDER_BIN to the full path of your Blender executable, then try again.
  pause
)
