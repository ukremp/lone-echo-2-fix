@echo off
setlocal DisableDelayedExpansion
echo Close the game before continuing.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0001-fix-loading.ps1" 
set "LE2_RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %LE2_RESULT%