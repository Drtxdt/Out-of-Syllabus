param([string]$Godot,[string]$Binary,[string]$RunId=('exe-'+[guid]::NewGuid().ToString('N')),[switch]$Render)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'toolchain.ps1')
. (Join-Path $PSScriptRoot 'v03_runner.ps1')
$run=New-V03Run (Split-Path $PSScriptRoot -Parent) $Godot $RunId
if(-not $Binary){$Binary=Join-Path $run.root 'build/v0.3/windows/OutOfSyllabusV03.exe'}
try {
 if(-not(Test-Path -LiteralPath $Binary)){throw "Missing v0.3 executable: $Binary"}
 $Binary=(Resolve-Path -LiteralPath $Binary).Path
 foreach($route in @('accept','refuse','natural-keyboard')){
  $args=@('--headless','--fixed-fps','60','--script','res://qa/v03_input.gd','--',"--route=$route")
  $null=Invoke-V03Check -Run $run -Name "exe-$route" -Arguments $args -TimeoutSeconds 300 -Executable $Binary -Standalone
 }
 if($Render){
  foreach($size in @('960x540','1280x720','1366x768','1920x1080')){
   $args=@('--fixed-fps','60','--resolution',$size,'--script','res://qa/v03_input.gd','--','--route=accept')
   $null=Invoke-V03Check -Run $run -Name "exe-render-$size" -Arguments $args -TimeoutSeconds 300 -Executable $Binary -Standalone
  }
 }
} catch {$run.errors.Add($_.Exception.Message)}
finally {
 $hash=if(Test-Path -LiteralPath $Binary){(Get-FileHash -LiteralPath $Binary -Algorithm SHA256).Hash}else{''}
 Complete-V03Run $run @{binary=$Binary;binary_sha256=$hash;standalone_without_project_path=$true}
}
if($run.errors.Count -gt 0){exit 1}
