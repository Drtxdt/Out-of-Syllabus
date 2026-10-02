param([string]$Godot = 'D:\Godot_v4.7.2\Godot_v4.7.2-stable_win64.exe')
$projectRoot = Split-Path $PSScriptRoot -Parent
& $Godot --path $projectRoot
