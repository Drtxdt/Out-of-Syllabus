param([string]$Godot)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$Godot = Resolve-GameGodot $Godot
# Official Forge opt-out for command-line import/export: no editor server needed.
$env:GODOT_FORGE_NO_SERVER = '1'
$projectRoot = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $projectRoot 'build/v0.2/windows'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
& $Godot --headless --path $projectRoot --export-release 'Windows Desktop' (Join-Path $destination 'OutOfSyllabus.exe')
if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/fonts/LICENSE.txt') -Destination (Join-Path $destination 'FONT-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $destination
