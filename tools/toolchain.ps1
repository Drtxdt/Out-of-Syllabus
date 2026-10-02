function Resolve-GameGodot([string]$Requested) {
 if (-not $Requested) { $Requested = $env:GODOT_PATH }
 if (-not $Requested) {
  $found = Get-Command godot,Godot -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { $Requested = $found.Source }
 }
 if (-not $Requested) { throw 'Set GODOT_PATH or pass -Godot with your Godot 4.7.2 executable.' }
 $resolved = (Resolve-Path -LiteralPath $Requested).Path
 $version = (& $resolved --version | Out-String).Trim()
 if ($LASTEXITCODE -ne 0 -or $version -ne '4.7.2.stable.official.ed1daf0bf') { throw "Expected locked Godot 4.7.2, got: $version" }
 return $resolved
}
function Get-PortableGameGodot([string]$Source, [string]$Root) {
 $folder = Join-Path $Root 'build/qa-engine'
 New-Item -ItemType Directory -Force -Path $folder | Out-Null
 $gui = $Source -replace '_console\.exe$', '.exe'
 foreach ($binary in @($gui,($gui -replace '\.exe$', '_console.exe'))) {
  if (Test-Path -LiteralPath $binary) {
   $target = Join-Path $folder (Split-Path $binary -Leaf)
   if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath $binary -Destination $target }
  }
 }
 Set-Content -LiteralPath (Join-Path $folder '_sc_') -Value ''
 return Join-Path $folder (Split-Path $Source -Leaf)
}
