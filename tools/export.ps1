param([string]$Godot, [string]$RunId = ('export-'+[guid]::NewGuid().ToString('N')), [string]$Templates)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$projectRoot = Split-Path $PSScriptRoot -Parent
$Godot = Get-PortableGameGodot (Resolve-GameGodot $Godot) $projectRoot
$env:GODOT_FORGE_NO_SERVER = '1'
$env:OOS_QA_PROFILE=$RunId
$reportRoot=Join-Path $projectRoot "reports/v0.2/$RunId"
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
if(-not $Templates){$Templates=Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'}
$localTemplates=Join-Path (Split-Path $Godot) 'editor_data/export_templates/4.7.2.stable'
New-Item -ItemType Directory -Force -Path $localTemplates | Out-Null
foreach($template in @('windows_debug_x86_64.exe','windows_release_x86_64.exe')) {
 $source=Join-Path $Templates $template
 if(-not (Test-Path -LiteralPath $source)){throw "Missing locked export template: $source"}
 Copy-Item -LiteralPath $source -Destination (Join-Path $localTemplates $template)
}
$destination = Join-Path $projectRoot 'build/v0.2/windows'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$binary=Join-Path $destination 'OutOfSyllabus.exe'
$arguments=@('--headless','--path',$projectRoot,'--log-file',(Join-Path $reportRoot 'export.log'),'--export-release','Windows Desktop',$binary)
$exportOutput=& $Godot @arguments 2>&1
$code=$LASTEXITCODE
Set-Content -LiteralPath (Join-Path $reportRoot 'process.txt') -Value $exportOutput
$failed=($code -ne 0 -or ($exportOutput -join "`n") -match '(?m)^(SCRIPT ERROR:|ERROR:)')
@{commit=(& git -C $projectRoot rev-parse HEAD | Out-String).Trim();engine='4.7.2.stable.official.ed1daf0bf';command=@($Godot)+$arguments;exit_code=$code;passed=(-not $failed);sha256=if(Test-Path -LiteralPath $binary){(Get-FileHash -LiteralPath $binary).Hash}else{''}} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $reportRoot 'manifest.json')
if($failed){throw "Export failed; see $reportRoot"}
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/fonts/LICENSE.txt') -Destination (Join-Path $destination 'FONT-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $destination
Write-Output "Exported $binary"
