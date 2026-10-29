<#
.SYNOPSIS
  Runs the headless test suites one by one, each with its own timeout, and lists only what went wrong.

.DESCRIPTION
  A suite that hits a script error before it calls quit() never exits, so a plain loop hangs forever (and a long
  loop gets reaped when memory runs low). Each suite runs in its own process here and is killed after -TimeoutSec;
  a timeout counts as a failure. A suite passes when it exits 0, prints at least one [PASS] and no [FAIL],
  SCRIPT ERROR or Parse Error. test_race_world runs with --fixed-fps 60.

.EXAMPLE
  powershell -File tools/run_tests.ps1                      # every tests/test_*.gd
  powershell -File tools/run_tests.ps1 -Filter "pit"        # suites whose name contains "pit"
  powershell -File tools/run_tests.ps1 -From 0 -To 20       # a slice, to stay under a tool time limit
#>
param(
  [string]$Filter = "",
  [int]$From = 0,
  [int]$To = -1,
  [int]$TimeoutSec = 400,
  [string]$Godot = $(if ($env:GODOT_CONSOLE) { $env:GODOT_CONSOLE } else { "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" })
)

$suites = @(Get-ChildItem (Join-Path $PSScriptRoot "..\tests") -Filter "test_*.gd" -Recurse |
  Where-Object { $_.BaseName -like "*$Filter*" } | Sort-Object Name | ForEach-Object { $_.BaseName })
if ($To -lt 0 -or $To -ge $suites.Count) { $To = $suites.Count - 1 }
$project = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$bad = @()
$watch = [Diagnostics.Stopwatch]::StartNew()
foreach ($name in $suites[$From..$To]) {
  $script = (Get-ChildItem (Join-Path $project "tests") -Filter "$name.gd" -Recurse | Select-Object -First 1)
  $res = "res://" + $script.FullName.Substring($project.Length + 1).Replace("\", "/")
  $args2 = @("--headless", "--path", $project)
  if ($name -eq "test_race_world") { $args2 += @("--fixed-fps", "60") }
  $args2 += @("-s", $res)
  $log = Join-Path $env:TEMP "suite_$name.log"
  $proc = Start-Process -FilePath $Godot -ArgumentList $args2 -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err"
  $null = $proc.Handle
  if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    $bad += "$name TIMEOUT after ${TimeoutSec}s"
    continue
  }
  $text = (Get-Content $log -Raw) + (Get-Content "$log.err" -Raw -ErrorAction SilentlyContinue)
  $passes = ([regex]::Matches($text, "(?m)^\[PASS\]")).Count
  $fails = ([regex]::Matches($text, "(?m)^\[FAIL\]|SCRIPT ERROR|Parse Error")).Count
  if ($proc.ExitCode -ne 0 -or $fails -ne 0 -or $passes -eq 0) { $bad += "$name exit=$($proc.ExitCode) pass=$passes fail=$fails" }
}
"ran $($To - $From + 1) of $($suites.Count) suites in $([int]$watch.Elapsed.TotalSeconds)s, failing: $($bad.Count)"
$bad
exit $(if ($bad.Count -gt 0) { 1 } else { 0 })
