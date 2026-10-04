# Shared v0.3 process runner. No production files or user data are modified.
function New-V03Run([string]$Root,[string]$Godot,[string]$RunId) {
 if($RunId -notmatch '^[A-Za-z0-9_-]+$'){throw 'RunId must contain only letters, digits, underscore or dash.'}
 $resolved=Resolve-GameGodot $Godot
 $project=(Resolve-Path -LiteralPath $Root).Path
 $workspace=(Split-Path $project -Leaf) -replace '[^A-Za-z0-9_-]','_'
 $report=Join-Path $project "reports/v0.3/$RunId"
 New-Item -ItemType Directory -Force -Path $report | Out-Null
 return @{root=$project;godot=$resolved;run_id=$RunId;workspace=$workspace;report=$report;qa_root=(Join-Path $project 'reports/v0.3');results=[System.Collections.Generic.List[object]]::new();errors=[System.Collections.Generic.List[string]]::new();started=[DateTime]::UtcNow.ToString('o')}
}
function Invoke-V03Check($Run,[string]$Name,[string[]]$Arguments,[int]$TimeoutSeconds=180,[string]$Executable='') {
 if(-not $Executable){$Executable=$Run.godot}
 $profile="$($Run.workspace)-$($Run.run_id)-$Name"
 $log=Join-Path $Run.report "$Name.log"
 $all=@('--path',$Run.root,'--log-file',$log)+$Arguments
 $info=[System.Diagnostics.ProcessStartInfo]::new($Executable)
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $info.Environment['GODOT_FORGE_NO_SERVER']='1'
 $info.Environment['OOS_QA_PROFILE']=$profile
 $info.Environment['OOS_QA_ROOT']=$Run.qa_root
 $info.Environment['OOS_QA_COMMIT']=(& git -C $Run.root rev-parse HEAD 2>$null | Out-String).Trim()
 foreach($arg in $all){$info.ArgumentList.Add($arg)}
 $process=[System.Diagnostics.Process]::new();$process.StartInfo=$info
 $watch=[System.Diagnostics.Stopwatch]::StartNew()
 $code=125;$output='';$timedOut=$false
 try {
  if(-not $process.Start()){throw 'Process start failed'}
  $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
  $timedOut=-not $process.WaitForExit($TimeoutSeconds*1000)
  if($timedOut){$process.Kill($true);$process.WaitForExit()}
  $output=$stdout.Result+$stderr.Result
  $code=if($timedOut){124}else{$process.ExitCode}
 } catch {$output+="`nRunner error: $($_.Exception.Message)"}
 finally {$watch.Stop();$process.Dispose()}
 $environmentError=$output -match 'Failed to read the root certificate store'
 $runtimeError=$output -match '(?m)^(SCRIPT ERROR:|ERROR:)'
 $passed=$code -eq 0 -and -not $runtimeError
 Set-Content -LiteralPath (Join-Path $Run.report "$Name-process.txt") -Value $output -Encoding utf8
 $entry=@{name=$Name;command=@($Executable)+$all;qa_profile=$profile;qa_root=$info.Environment['OOS_QA_ROOT'];exit_code=$code;timed_out=$timedOut;runtime_error=$runtimeError;environment_certificate_error=$environmentError;passed=$passed;elapsed_ms=$watch.ElapsedMilliseconds;log=$log}
 $Run.results.Add($entry)
 if(-not $passed){$Run.errors.Add("$Name failed: exit=$code runtime_error=$runtimeError")}
 Write-Output "$Name : exit=$code runtime_error=$runtimeError elapsed_ms=$($watch.ElapsedMilliseconds)"
 return $entry
}
function Complete-V03Run($Run,[hashtable]$Extra=@{}) {
 $manifest=@{version='v0.3';run_id=$Run.run_id;workspace=$Run.workspace;project=$Run.root;started_utc=$Run.started;finished_utc=[DateTime]::UtcNow.ToString('o');commit=(& git -C $Run.root rev-parse HEAD | Out-String).Trim();working_tree=@(& git -C $Run.root status --porcelain);engine='4.7.2.stable.official.ed1daf0bf';checks=$Run.results.ToArray();errors=$Run.errors.ToArray();passed=$Run.errors.Count -eq 0;limitations=@('No human blind playtest','No OS scaling validation','No physical disk loss or full-disk test','Headless input is not visual acceptance','Fixed-fps simulation is not a human duration or FPS measurement')}
 foreach($key in $Extra.Keys){$manifest[$key]=$Extra[$key]}
 $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Run.report 'manifest.json') -Encoding utf8
}
