@echo off
rem Double-click to install or update Ashwright for WoW Forever.
rem Add -Force after the .ps1 path to reinstall even if you're up to date.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Ashwright.ps1" %*
echo.
pause
