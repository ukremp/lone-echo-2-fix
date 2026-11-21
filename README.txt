LONE ECHO II - TWO SEPARATE FIXES
Place this patches folder beside loneecho2.exe (usually bin\win10).
Close the game, then double-click a command below. No admin needed normally.

001 - Save/loading fix
Removes script DLL download markers that caused extremely slow game loading.
Apply: Apply-001.cmd    Undo: Undo-001.cmd
Undo restores markers saved by this version in .undo-001; keep that folder.
Markers removed by the older version without backups cannot be restored.

002 - Texture streaming retry (experimental)
Reduces the texture-upgrade retry wait from 5000 ms to 100 ms.
Apply: Apply-002.cmd    Undo: Undo-002.cmd (restores original 5000 ms)
Also upgrades the previous 500 ms patch. Gameplay improvement is unverified.

Both fixes: Apply.cmd    Undo both: Undo.cmd (002 first, then 001)
Re-running commands is safe. Unknown executable builds are refused by 002.
Saves are unchanged. Keep .undo-001 private; do not include it when sharing.