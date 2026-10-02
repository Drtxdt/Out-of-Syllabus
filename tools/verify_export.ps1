param([string]$RunId=('exe-'+[guid]::NewGuid().ToString('N')), [switch]$Render, [string]$Resolution='1366x768')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$binary=Join-Path $projectRoot 'build/v0.2/windows/OutOfSyllabus.exe'
$reportRoot=Join-Path $projectRoot "reports/v0.2/$RunId"
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
$env:GODOT_FORGE_NO_SERVER='1'
$env:OOS_QA_ROOT=Join-Path $projectRoot 'reports/v0.2'
$results=[System.Collections.Generic.List[object]]::new()
$failure=$null
try {
 foreach($route in @('accept','refuse')) {
  $env:OOS_QA_PROFILE="$RunId-$route"
  $caseRoot=Join-Path $env:OOS_QA_ROOT $env:OOS_QA_PROFILE
  New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null
  $arguments=@('--fixed-fps','60','--log-file',(Join-Path $caseRoot 'engine.log'))
  if(-not $Render){$arguments+=@('--headless')}else{$arguments+=@('--resolution',$Resolution)}
  $arguments+=@('--','--qa-input',"--route=$(Join-Path $projectRoot "tests/routes/$route.json")")
  $info=[System.Diagnostics.ProcessStartInfo]::new($binary)
  $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WorkingDirectory=Split-Path $binary
  $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
  foreach($argument in $arguments){$info.ArgumentList.Add($argument)}
  $process=[System.Diagnostics.Process]::new();$process.StartInfo=$info
  $watch=[System.Diagnostics.Stopwatch]::StartNew()
  if(-not $process.Start()){throw 'Standalone process did not start'}
  $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
  $timeout=-not $process.WaitForExit(180000)
  if($timeout){$process.Kill($true);$process.WaitForExit()}
  $output=$stdout.Result+$stderr.Result
  Set-Content -LiteralPath (Join-Path $caseRoot 'process.txt') -Value $output
  $resultFile=Join-Path $caseRoot 'input-walkthrough.json'
  $result=if(Test-Path -LiteralPath $resultFile){Get-Content -Raw -LiteralPath $resultFile | ConvertFrom-Json}else{$null}
  $code=if($timeout){124}else{$process.ExitCode}
  $runtimeError=$output -match '(?m)^(SCRIPT ERROR:|ERROR:)'
  $ok=($code -eq 0 -and -not $runtimeError -and $result -and $result.completion -and $result.failures.Count -eq 0)
  $results.Add(@{route=$route;command=@($binary)+$arguments;exit_code=$code;passed=[bool]$ok;runtime_error=$runtimeError;elapsed_ms=$watch.ElapsedMilliseconds;report=$resultFile})
  Write-Output "Standalone $route : exit $code; passed $ok"
  if(-not $ok){throw "Standalone $route failed; see $caseRoot"}
 }
}catch{$failure=$_.Exception.Message;Write-Output $failure}
finally {
 @{commit=(& git -C $projectRoot rev-parse HEAD | Out-String).Trim();sha256=(Get-FileHash -LiteralPath $binary).Hash;checks=$results;failure=$failure;passed=($null -eq $failure)} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $reportRoot 'manifest.json')
}
if($failure){exit 1}
