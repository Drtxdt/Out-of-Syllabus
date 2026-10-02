param([string]$Godot)
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$Godot = Resolve-GameGodot $Godot
$projectRoot = Split-Path $PSScriptRoot -Parent
& $Godot --path $projectRoot
