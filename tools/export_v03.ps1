param([string]$Godot,[string]$RunId=('export-'+[guid]::NewGuid().ToString('N')),[string]$Templates)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'toolchain.ps1')
. (Join-Path $PSScriptRoot 'v03_runner.ps1')
$run=New-V03Run (Split-Path $PSScriptRoot -Parent) $Godot $RunId
$destination=Join-Path $run.root 'build/v0.3/windows'
$stage=Join-Path $run.root "build/v0.3/staging/$RunId"
$binary=Join-Path $destination 'OutOfSyllabusV03.exe'
try {
 # Copy into a fresh staging tree, then change only staged project/preset metadata.
 if(Test-Path -LiteralPath $stage){throw 'Export staging directory already exists; choose a new run ID.'}
 New-Item -ItemType Directory -Force -Path $stage,$destination | Out-Null
 foreach($entry in Get-ChildItem -LiteralPath $run.root -Force){
  if($entry.Name -in @('.git','.godot','.codex','.agents','build','reports')){continue}
  Copy-Item -LiteralPath $entry.FullName -Destination $stage -Recurse -Force
 }
 $projectPath=Join-Path $stage 'project.godot'
 $project=Get-Content -Raw -LiteralPath $projectPath
 $project=[regex]::Replace($project,'(?m)^run/main_scene=.*$','run/main_scene="res://app/v03/main.tscn"')
 Set-Content -LiteralPath $projectPath -Value $project -Encoding utf8
 $presetPath=Join-Path $stage 'export_presets.cfg'
 $preset=Get-Content -Raw -LiteralPath $presetPath
 $preset=[regex]::Replace($preset,'(?m)^exclude_filter=.*$','exclude_filter="tools/*,tests/*,reports/*,docs/*,art_source/*,assets/art_source/*,.codex/*"')
 $preset=[regex]::Replace($preset,'(?m)^include_filter=.*$','include_filter="qa/v03_*.gd,qa/v03_routes/*.json"')
 $preset=$preset.Replace('0.2.0.0','0.3.0.0')
 if($Templates){
  foreach($type in @('debug','release')){
   $template=Join-Path $Templates "windows_${type}_x86_64.exe"
   if(-not(Test-Path -LiteralPath $template)){throw "Missing locked export template $template"}
   $normalized=$template.Replace('\','/')
   $preset=[regex]::Replace($preset,"(?m)^custom_template/$type=.*$",('custom_template/'+$type+'="'+$normalized+'"'))
  }
 }
 Set-Content -LiteralPath $presetPath -Value $preset -Encoding utf8
 $stageRun=$run.Clone();$stageRun.root=$stage
 $null=Invoke-V03Check $stageRun 'staged-import' @('--headless','--editor','--import','--quit')
 if($run.errors.Count -eq 0){$null=Invoke-V03Check $stageRun 'export' @('--headless','--export-release','Windows Desktop',$binary) 300}
 if($run.errors.Count -eq 0 -and -not(Test-Path -LiteralPath $binary)){$run.errors.Add('Exporter returned success without binary')}
 if($run.errors.Count -eq 0){
  Copy-Item -LiteralPath (Join-Path $run.root 'assets/fonts/LICENSE.txt') -Destination (Join-Path $destination 'FONT-LICENSE.txt')
  Set-Content -LiteralPath (Join-Path $destination 'PLAYTEST-STATUS.txt') -Value 'v0.3 local release candidate. Automated verification and visual evidence are separate. Human blind playtest is pending. Existing v0.2 builds and saves are retained.'
 }
} catch {$run.errors.Add($_.Exception.Message)}
finally {
 $hash=if(Test-Path -LiteralPath $binary){(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash}else{''}
 Complete-V03Run $run @{binary=$binary;binary_sha256=$hash;staging=$stage}
}
if($run.errors.Count -gt 0){exit 1}
