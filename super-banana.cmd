@echo off
rem Sets up this machine and updates every Super Banana project in this folder.
cd /d "%~dp0"
goto run
rem Keep this line 105 bytes long, so the pause below is where a launcher from before 2026-10-15 goes on.
pause
goto :eof
:run
curl.exe -fsSL -o "%TEMP%\superb-setup.ps1" https://super-banana-studios.github.io/setup.ps1 && powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%TEMP%\superb-setup.ps1" -Repo Super-Banana-Studios/setup
pause
