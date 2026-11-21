# Lone Echo II - Texture streaming retry, version 0.2 (2026-11-22)
#
# INSTALL: Close the game and run Apply.cmd in this folder.
# UNDO: Run Undo-002.cmd, or invoke this script with -Undo.
# INSPECT: Invoke this script with -Check (does not write anything).
# Requires Windows PowerShell 5.1. Keep this folder beside loneecho2.exe.
# Also supports placing this script directly beside the executable.
#
# EXPERIMENTAL: Static analysis confirms the change below. Gameplay benefit
# has NOT been measured. Compare the same save and route before/after; undo
# if texture delays do not improve or frame-time spikes increase.
#
# CHANGE: Reduce the texture-upgrade allocation retry cooldown from 5000 ms
# to 100 ms. Allocation failure records a timestamp in the streaming manager;
# its upgrade dispatcher defers higher-resolution requests until this elapsed
# time passes. The low-memory path also refreshes that timestamp. A persistent
# shortage still prevents upgrades: this patch does not bypass that check.
#
# The mip selection, texture budgets, four-upgrade dispatch limit, 64-request
# pool, allocation checks, and downgrade path remain intact. No code injection,
# new threads, forced full-resolution textures, or save modifications.
#
# EVIDENCE (original executable, preferred image base 0x140000000):
#   0x14058DB5A..0x14058DB5F: failed allocation updates manager +0x150.
#   0x140577236..0x140577242: low-memory path updates the same timestamp.
#   0x1405B9CBF..0x1405B9D1C: QPC elapsed time converted to milliseconds,
#     compared with the 64-bit cooldown at VA 0x141E54D48 (only found xref).
#   .data RVA 0x1E54D48 -> file offset 0x1E53548:
#     88 13 00 00 00 00 00 00 -> 64 00 00 00 00 00 00 00.
# Only two byte values change. Executable length and instructions do not.
#
# Full-file SHA256 checks reject other builds or unknown binary modifications.
# Re-running apply/undo is safe. Undo restores the exact original file hash;
# it does not reverse patch 001 (which changes script-DLL download metadata).
# The previous 500 ms version is recognized and upgraded directly to 100 ms.
# Undo also accepts the previous version and restores the original 5000 ms.
# No backup is needed to reverse this fixed-byte edit. An exclusive file lock
# is held through validation/write/verification; close the game first.
# Running Apply.cmd after undoing this patch will apply it again.

[CmdletBinding()]
param([switch]$Undo, [switch]$Check)

$ErrorActionPreference = 'Stop'
if ($Undo -and $Check) { throw 'Use either -Undo or -Check, not both.' }

$gamePath = $null
foreach ($candidate in @($PSScriptRoot, (Split-Path -Parent $PSScriptRoot))) {
    $path = Join-Path $candidate 'loneecho2.exe'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $gamePath = [IO.Path]::GetFullPath($path)
        break
    }
}
if (!$gamePath) { throw 'Game not found. Put patches beside loneecho2.exe.' }
if ((Get-Item -LiteralPath $gamePath).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'The executable is a link. Use the actual game installation.'
}

$originalHash = '1aac73d7a5f41b8f08ef2e26b54209ff800916559e9ab94ec7f609459c7d81c1'
$previousHash = '9aceb43907d28e8b113901648e1924e18ebbbe52bbe31103039104e667b071a9'
$patchedHash = 'cc1ce80e41a1d48d178bc932030631c0a7d4931e5e9863959763837c2744ba95'
$patchOffset = [long]0x1E53548
$originalValue = [UInt64]5000
$previousValue = [UInt64]500
$patchedValue = [UInt64]100
$stream = $null
$hasher = [Security.Cryptography.SHA256]::Create()

try {
    $access = [IO.FileAccess]::ReadWrite
    $sharing = [IO.FileShare]::None
    if ($Check) {
        $access = [IO.FileAccess]::Read
        $sharing = [IO.FileShare]::Read
    }
    try { $stream = [IO.File]::Open($gamePath, [IO.FileMode]::Open, $access, $sharing) }
    catch { throw ('Cannot open the game executable. Close the game and try again. ' + $_.Exception.Message) }

    if ($stream.Length -ne 33436160) { throw 'Unsupported executable size. Nothing changed.' }
    $hash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
    if ($hash -ne $originalHash -and $hash -ne $previousHash -and $hash -ne $patchedHash) {
        throw ('Unsupported or modified executable (SHA256 ' + $hash + '). Nothing changed.')
    }
    $isPatched = $hash -eq $patchedHash
    $isPrevious = $hash -eq $previousHash
    if ($Check) {
        if ($isPatched) { Write-Host 'Patch 002 is applied: texture retry cooldown = 100 ms (experimental).' }
        elseif ($isPrevious) { Write-Host 'Patch 002 previous version is applied: 500 ms. Run Apply.cmd to upgrade to 100 ms.' }
        else { Write-Host 'Patch 002 is not applied: original texture retry cooldown = 5000 ms.' }
        return
    }
    if (($Undo -and $hash -eq $originalHash) -or (!$Undo -and $isPatched)) {
        if ($Undo) { Write-Host 'Patch 002 is already undone. Original executable verified.' }
        else { Write-Host 'Patch 002 is already applied. Patched executable verified.' }
        return
    }

    $beforeValue = $originalValue
    if ($isPrevious) { $beforeValue = $previousValue }
    elseif ($isPatched) { $beforeValue = $patchedValue }
    $afterValue = $patchedValue
    $expectedHash = $patchedHash
    if ($Undo) {
        $afterValue = $originalValue
        $expectedHash = $originalHash
    }
    $beforeBytes = [BitConverter]::GetBytes($beforeValue)
    $afterBytes = [BitConverter]::GetBytes($afterValue)
    $actualBytes = New-Object byte[] 8
    $stream.Position = $patchOffset
    if ($stream.Read($actualBytes, 0, 8) -ne 8 -or [BitConverter]::ToUInt64($actualBytes, 0) -ne $beforeValue) {
        throw 'Cooldown bytes did not match. Nothing changed.'
    }

    try {
        $stream.Position = $patchOffset
        $stream.Write($afterBytes, 0, $afterBytes.Length)
        $stream.Flush($true)
        $stream.Position = 0
        $resultHash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
        if ($resultHash -ne $expectedHash) { throw 'Post-write SHA256 verification failed.' }
    } catch {
        $writeError = $_.Exception.Message
        try {
            $stream.Position = $patchOffset
            $stream.Write($beforeBytes, 0, $beforeBytes.Length)
            $stream.Flush($true)
            $stream.Position = 0
            $restoredHash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
            if ($restoredHash -ne $hash) { throw 'Restored file hash does not match.' }
        } catch {
            throw ('Write and recovery failed. Restore loneecho2.exe from your installation source before launching. ' + $_.Exception.Message)
        }
        throw ('Patch operation failed; original input was restored and verified. ' + $writeError)
    }
    if ($Undo) { Write-Host 'Patch 002 undone. Exact original executable restored; patch 001 remains in effect.' }
    else { Write-Host ('Patch 002 applied: texture retry {0} -> 100 ms. SHA256 verified. Gameplay benefit still needs testing.' -f $beforeValue) }
} finally {
    if ($stream) { $stream.Dispose() }
    $hasher.Dispose()
}
