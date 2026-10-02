param([switch]$Render, [string]$Godot = 'D:\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
# Official Forge opt-out for command-line import/export: no editor server needed.
$env:GODOT_FORGE_NO_SERVER = '1'
$projectRoot = Split-Path $PSScriptRoot -Parent
& $Godot --headless --path $projectRoot --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
& $Godot --headless --path $projectRoot --script res://tests/regression.gd
if ($LASTEXITCODE -ne 0) { throw 'Regression failed' }
if ($Render) {
 & $Godot --path $projectRoot --script res://tests/gui_smoke.gd --log-file (Join-Path $projectRoot 'reports/gui.log')
 if ($LASTEXITCODE -ne 0) { throw 'Scene smoke failed' }
}
