param([string]$Godot,[string]$RunId=('verify-'+[guid]::NewGuid().ToString('N')),[switch]$Render,[switch]$SkipInput)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'toolchain.ps1')
. (Join-Path $PSScriptRoot 'v03_runner.ps1')
$run=New-V03Run (Split-Path $PSScriptRoot -Parent) $Godot $RunId
try {
 $import=Invoke-V03Check $run 'import' @('--headless','--editor','--import','--quit')
 foreach($suite in @('physics','combat','echo','save','performance')) {
  $null=Invoke-V03Check $run $suite @('--headless','--script',"res://tests/v03_$suite.gd")
 }
 if(-not $SkipInput){
  foreach($route in @('accept','refuse','natural-keyboard')){
   $null=Invoke-V03Check $run "input-$route" @('--headless','--fixed-fps','60','--script','res://qa/v03_input.gd','--',"--route=$route") 300
  }
 }
 if($Render){
  foreach($size in @('960x540','1280x720','1366x768','1920x1080')){
   $null=Invoke-V03Check $run "render-$size" @('--fixed-fps','60','--resolution',$size,'--script','res://qa/v03_input.gd','--','--route=accept') 300
  }
 }
} catch {$run.errors.Add($_.Exception.Message)}
finally {Complete-V03Run $run}
if($run.errors.Count -gt 0){exit 1}
