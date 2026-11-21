# Lone Echo II - Script DLL loading fix, version 1.1 (2026-11-22)
#
# INSTALL: Extract the patches folder beside loneecho2.exe, then double-click
# patches\Apply.cmd. Alternatively, put both files beside loneecho2.exe.
# Use this on your intentionally installed, trusted copy of the game.
# Requires Windows PowerShell 5.1 (included in Windows 10/11).
#
# FIX: Removes the Zone.Identifier (Internet download marker) alternate stream
# only from scripts\<16 hexadecimal characters>.dll. DLL code, saves, settings,
# and system security settings are not changed. Original markers are saved in
# .undo-001 beside this script before removal. Keep it for Undo-001.cmd.
# -Undo restores those exact markers; version 1.0 removals had no backups and
# cannot be reversed by this script. No DLL code or saves are backed up.
# It is safe to run again; already unmarked DLLs are skipped. Reapply if a game
# reinstall or a freshly extracted download restores the markers.
#
# EVIDENCE: During the affected live load, script module count grew by only
# 15 in 64 seconds. After clearing the markers, it grew by 1,186 in 27 seconds.
# The user then confirmed gameplay. This fixes the observed metadata-related
# delay; it does not establish that every loading hang has the same cause.
# Microsoft API documentation:
# https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/unblock-file
#
# FUTURE PATCHES: Add reviewed scripts as 002-name.ps1, 003-name.ps1, etc.
# Apply.cmd runs them in filename order and stops on a terminating error.
# Scripts should be repeatable, throw on failure, and not call exit themselves.
# The launcher's execution-policy override applies only to its PowerShell
# process; it does not change the user's saved execution-policy settings.

[CmdletBinding()]
param([switch]$Undo)

$ErrorActionPreference = 'Stop'
$installCandidates = @($PSScriptRoot, (Split-Path -Parent $PSScriptRoot))
$gameDirectory = $null
foreach ($candidate in $installCandidates) {
    if ((Test-Path -LiteralPath (Join-Path $candidate 'loneecho2.exe') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $candidate 'scripts') -PathType Container)) {
        $gameDirectory = $candidate
        break
    }
}
if (!$gameDirectory) {
    throw 'Game not found. Put the patches folder beside loneecho2.exe (usually bin\win10), then run Apply.cmd.'
}

$scriptsDirectory = Join-Path $gameDirectory 'scripts'
if ((Get-Item -LiteralPath $scriptsDirectory).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'The scripts folder is a link. Place this patch in the actual game installation.'
}
$scriptDlls = @(Get-ChildItem -LiteralPath $scriptsDirectory -Filter '*.dll' -File |
    Where-Object { $_.Name -match '^[0-9a-fA-F]{16}\.dll$' })
if ($scriptDlls.Count -eq 0) { throw 'No matching game script DLLs found. Nothing was changed.' }

$backupDirectory = Join-Path $PSScriptRoot '.undo-001'
$ownerPath = Join-Path $backupDirectory 'installation.txt'
if (Test-Path -LiteralPath $backupDirectory) {
    if ((Get-Item -LiteralPath $backupDirectory).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'The patch 001 backup folder is a link.'
    }
    if (!(Test-Path -LiteralPath $ownerPath) -or
        [IO.File]::ReadAllText($ownerPath) -ne [IO.Path]::GetFullPath($gameDirectory)) {
        throw 'Patch 001 backups belong to a different installation or are incomplete.'
    }
}

if ($Undo) {
    if (!(Test-Path -LiteralPath $backupDirectory)) {
        Write-Host 'Patch 001: no saved markers to restore. Removals by version 1.0 cannot be undone here.'
        return
    }
    $backups = @(Get-ChildItem -LiteralPath $backupDirectory -File |
        Where-Object { $_.Name -match '^[0-9a-fA-F]{16}\.dll\.zone$' })
    # Validate the complete restore set before writing any markers.
    foreach ($backup in $backups) {
        $dllPath = Join-Path $scriptsDirectory ($backup.Name -replace '\.zone$', '')
        if ($backup.Attributes -band [IO.FileAttributes]::ReparsePoint -or
            !(Test-Path -LiteralPath $dllPath -PathType Leaf) -or
            ((Get-Item -LiteralPath $dllPath).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw ('Missing or linked restore target: ' + $dllPath)
        }
        try {
            $currentMarker = [IO.File]::ReadAllBytes($dllPath + ':Zone.Identifier')
            if ([Convert]::ToBase64String($currentMarker) -ne
                [Convert]::ToBase64String([IO.File]::ReadAllBytes($backup.FullName))) {
                throw ('A different download marker exists; refusing to overwrite it: ' + $dllPath)
            }
        } catch [IO.FileNotFoundException] { }
    }
    foreach ($backup in $backups) {
        $zonePath = (Join-Path $scriptsDirectory ($backup.Name -replace '\.zone$', '')) + ':Zone.Identifier'
        $marker = [IO.File]::ReadAllBytes($backup.FullName)
        [IO.File]::WriteAllBytes($zonePath, $marker)
        if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($zonePath)) -ne [Convert]::ToBase64String($marker)) {
            throw ('Marker restore verification failed: ' + $zonePath)
        }
        Remove-Item -LiteralPath $backup.FullName
    }
    Write-Host ('Patch 001: restored {0} saved download markers. Earlier unbacked removals remain unchanged.' -f $backups.Count)
    return
}

$unblocked = 0
$alreadyUnmarked = 0
foreach ($dll in $scriptDlls) {
    if ($dll.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw ('Linked DLL encountered; stopped at ' + $dll.FullName)
    }
    $zonePath = $dll.FullName + ':Zone.Identifier'
    # Direct stream access avoids opening/hashing every DLL's executable data.
    # File.Exists alone would also hide permission failures as missing markers.
    try { $marker = [IO.File]::ReadAllBytes($zonePath) }
    catch [IO.FileNotFoundException] {
        $alreadyUnmarked++
        continue
    }

    if (!(Test-Path -LiteralPath $backupDirectory)) {
        New-Item -ItemType Directory -Path $backupDirectory | Out-Null
        [IO.File]::WriteAllText($ownerPath, [IO.Path]::GetFullPath($gameDirectory))
    }
    $backupPath = Join-Path $backupDirectory ($dll.Name + '.zone')
    if (!(Test-Path -LiteralPath $backupPath)) {
        $backupStream = [IO.File]::Open($backupPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $backupStream.Write($marker, 0, $marker.Length); $backupStream.Flush($true) }
        finally { $backupStream.Dispose() }
    }
    if (((Get-Item -LiteralPath $backupPath).Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($backupPath)) -ne [Convert]::ToBase64String($marker)) {
        throw ('Saved marker differs or is linked; nothing removed from ' + $dll.FullName)
    }
    Unblock-File -LiteralPath $dll.FullName -ErrorAction Stop
    $markerRemains = $false
    try {
        $null = [IO.File]::ReadAllBytes($zonePath)
        $markerRemains = $true
    } catch [IO.FileNotFoundException] {
        # Expected: removal succeeded.
    }
    if ($markerRemains) { throw ('Could not remove the download marker: ' + $dll.FullName) }
    $unblocked++
}

Write-Host ('Game: ' + $gameDirectory)
Write-Host ('Script DLLs checked: {0}; unblocked: {1}; already unmarked: {2}.' -f
    $scriptDlls.Count, $unblocked, $alreadyUnmarked)
if ($unblocked -eq 0) {
    Write-Host 'This fix is already applied. If loading still stalls, another cause needs investigation.'
}
