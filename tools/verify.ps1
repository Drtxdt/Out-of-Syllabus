param([switch]$Render, [string]$Godot, [string]$RunId = ([guid]::NewGuid().ToString('N')))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$Godot = Resolve-GameGodot $Godot
# Official Forge opt-out for command-line import/export: no editor server needed.
$env:GODOT_FORGE_NO_SERVER = '1'
$projectRoot = Split-Path $PSScriptRoot -Parent
$Godot = Get-PortableGameGodot $Godot $projectRoot
$reportRoot = Join-Path $projectRoot "reports/v0.2/$RunId"
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
$env:OOS_QA_PROFILE = $RunId
Write-Output "Project: $projectRoot; QA: $RunId; Godot: $Godot"
& $Godot --headless --path $projectRoot --editor --import --log-file (Join-Path $reportRoot 'import.log')
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
& $Godot --headless --path $projectRoot --script res://tests/regression.gd --log-file (Join-Path $reportRoot 'regression.log')
if ($LASTEXITCODE -ne 0) { throw 'Regression failed' }
if ($Render) {
 & $Godot --path $projectRoot --script res://tests/gui_smoke.gd --log-file (Join-Path $projectRoot "reports/v0.2/$RunId/gui.log")
 if ($LASTEXITCODE -ne 0) { throw 'Scene smoke failed' }
}
