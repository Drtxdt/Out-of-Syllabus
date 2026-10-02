param([switch]$Render, [string]$Godot, [string]$RunId = ([guid]::NewGuid().ToString('N')))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$projectRoot = Split-Path $PSScriptRoot -Parent
$Godot = Get-PortableGameGodot (Resolve-GameGodot $Godot) $projectRoot
$reportRoot = Join-Path $projectRoot "reports/v0.2/$RunId"
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
$env:GODOT_FORGE_NO_SERVER = '1'
$env:OOS_QA_ROOT = Join-Path $projectRoot 'reports/v0.2'
$results = [System.Collections.Generic.List[object]]::new()
$failure = $null
function Invoke-Check([string]$Name, [string[]]$Arguments) {
 $env:OOS_QA_PROFILE = "$RunId-$Name"
 $log = Join-Path $reportRoot "$Name.log"
 $all = @('--path',$projectRoot,'--log-file',$log) + $Arguments
 $info = [System.Diagnostics.ProcessStartInfo]::new($Godot)
 $info.UseShellExecute=$false; $info.CreateNoWindow=$true
 $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
 foreach($argument in $all) { $info.ArgumentList.Add($argument) }
 $process=[System.Diagnostics.Process]::new(); $process.StartInfo=$info
 $watch=[System.Diagnostics.Stopwatch]::StartNew()
 if(-not $process.Start()) { throw "Cannot launch $Name" }
 $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
 $timedOut=-not $process.WaitForExit(90000)
 if($timedOut) { $process.Kill($true); $process.WaitForExit() }
 $output=$stdout.Result + $stderr.Result
 Set-Content -LiteralPath (Join-Path $reportRoot "$Name-process.txt") -Value $output
 $runtimeError=$output -match '(?m)^(SCRIPT ERROR:|ERROR:)'
 $code=if($timedOut){124}else{$process.ExitCode}
 $results.Add(@{name=$Name;command=@($Godot)+$all;exit_code=$code;runtime_error=$runtimeError;elapsed_ms=$watch.ElapsedMilliseconds;log=$log;profile=$env:OOS_QA_PROFILE})
 Write-Output "$Name : exit $code, runtime errors $runtimeError"
 if($code -ne 0 -or $runtimeError) { throw "$Name failed; see $log and process output" }
}
try {
 Invoke-Check 'import' @('--headless','--editor','--import')
 Invoke-Check 'domain' @('--headless','--script','res://tests/v02_regression.gd')
 Invoke-Check 'adversarial' @('--headless','--script','res://tests/adversarial_contracts.gd')
 Invoke-Check 'views' @('--headless','--script','res://ui/verify_views.gd')
 Invoke-Check 'layout' @('--headless','--script','res://ui/verify_layout.gd')
 Invoke-Check 'archive' @('--headless','--script','res://tests/archive_performance.gd')
 foreach($route in @('accept','refuse')) {
  Invoke-Check "input-$route" @('--headless','--fixed-fps','60','--script','res://tests/input_walkthrough.gd','--',"--route=res://tests/routes/$route.json")
 }
 if($Render) {
  foreach($size in @('960x540','1280x720','1366x768','1920x1080')) {
   Invoke-Check "render-$size" @('--fixed-fps','60','--resolution',$size,'--script','res://tests/input_walkthrough.gd','--','--route=res://tests/routes/accept.json')
  }
 }
 $node=(Get-Command node -ErrorAction Stop).Source
 $nodeResult=& $node --test --test-isolation=none (Join-Path $projectRoot 'tests/forge_results.test.mjs') 2>&1
 $nodeCode=$LASTEXITCODE
 Set-Content -LiteralPath (Join-Path $reportRoot 'node-tests.txt') -Value $nodeResult
 $results.Add(@{name='node-result-parser';command=@($node,'--test','--test-isolation=none','tests/forge_results.test.mjs');exit_code=$nodeCode})
 if($nodeCode -ne 0) { throw 'Node result parsing tests failed' }
} catch { $failure=$_.Exception.Message; Write-Output $failure }
finally {
 $commit=(& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
 $dirty=@(& git -C $projectRoot diff --name-only)
 @{run_id=$RunId;project=$projectRoot;commit=$commit;dirty=$dirty;engine='4.7.2.stable.official.ed1daf0bf';checks=$results;failure=$failure;passed=($null -eq $failure);limitations=@('No human blind playtest','No operating-system DPI scaling validation','Rendered route uses fixed-fps simulation; measured process times are separate')} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $reportRoot 'manifest.json')
}
if($failure) { exit 1 }
