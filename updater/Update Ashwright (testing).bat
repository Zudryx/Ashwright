@echo off
rem Installs the newest Ashwright TEST build (a GitHub pre-release that never
rem goes to CurseForge). Use "Update Ashwright.bat" for normal releases.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Ashwright.ps1" -Testing %*
echo.
pause
