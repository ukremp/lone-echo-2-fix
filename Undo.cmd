@echo off
setlocal DisableDelayedExpansion
title Lone Echo II - Local patches
set "LE2_PATCH_DIR=%~dp0"
echo Lone Echo II - Local patches
echo Close the game before undoing patches, then launch it normally.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { $patches = @(Get-ChildItem -LiteralPath $env:LE2_PATCH_DIR -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[0-9]{3}-.+\.ps1$' } | Sort-Object Name -Descending); if ($patches.Count -eq 0) { throw 'No numbered patch scripts found beside Apply.cmd.' }; foreach ($patch in $patches) { Write-Host ('Undoing ' + $patch.Name); & $patch.FullName -Undo; Write-Host '' }; Write-Host 'Undo commands completed. Check the messages above for any unavailable backups.'; exit 0 } catch { Write-Host ('PATCH FAILED: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"
set "LE2_PATCH_RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %LE2_PATCH_RESULT%
