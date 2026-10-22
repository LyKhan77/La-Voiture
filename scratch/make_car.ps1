<#
One command for the per-car asset pipeline. Runs the stages in order and stops at the first failure, so no gate can be skipped:
  refine -> install -> import -> gate -> full -> test -> review
    powershell -File scratch\make_car.ps1 -Car aston_vantage            all stages
    powershell -File scratch\make_car.ps1 -Car aston_vantage -From gate  start at a later stage (the earlier ones are skipped)
    powershell -File scratch\make_car.ps1 -Car aston_vantage -DryRun     print what each stage would do, change nothing
Needs: scratch\car_configs\<car>.json, scenes\car\<car>_chassis.tscn, tests\test_<car>_chassis.gd (copy them from the nearest car, add the car to
CARS in scratch\fit_cars.gd), and Blender and Godot at the paths below (or set BLENDER_BIN / GODOT_BIN).
The review stage renders close-ups into temp\wheel_review\ and cannot judge them: LOOK at the "high" views of the front wheel before you call the car done.
Refining needs 4 to 6 GB of free RAM; the script refuses to start otherwise (-Force overrides). Run one car at a time.
#>
param(
    [Parameter(Mandatory = $true)][string]$Car,
    [ValidateSet("refine", "install", "import", "gate", "full", "test", "review")][string]$From = "refine",
    [switch]$DryRun,
    [switch]$Force,
    [switch]$NoReview
)
$ErrorActionPreference = "Stop"
$Project = Split-Path $PSScriptRoot -Parent
$Blender = if ($env:BLENDER_BIN) { $env:BLENDER_BIN } else { "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" }
$Godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "C:\Users\Lee\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }
$Config = Join-Path $Project "scratch\car_configs\$Car.json"
$Out = Join-Path $Project "temp\make_car\$Car"
$stages = "refine", "install", "import", "gate", "full", "test", "review"

function Fail($msg) { throw "make_car $Car : $msg" }

# Runs an executable, keeps its output in $log, returns the exit code.
function Run($exe, $argList, $log) {
    $err = [System.IO.Path]::ChangeExtension($log, ".err.txt")
    $p = Start-Process -FilePath $exe -ArgumentList $argList -WorkingDirectory $Project -NoNewWindow -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError $err
    return $p.ExitCode
}

function Stage($name, [scriptblock]$body) {
    if ($stages.IndexOf($name) -lt $stages.IndexOf($From)) { return }
    Write-Host ("[{0}] {1}" -f (Get-Date -Format HH:mm:ss), $name)
    if ($DryRun) { Write-Host "    (dry run)"; return }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $body
    Write-Host ("    ok ({0:n0}s)" -f $sw.Elapsed.TotalSeconds)
}

if (-not (Test-Path $Config)) { Fail "no config $Config" }
$cfg = Get-Content $Config -Raw | ConvertFrom-Json
if (-not (Test-Path (Join-Path $Project "scenes\car\${Car}_chassis.tscn"))) { Fail "scenes\car\${Car}_chassis.tscn is missing (copy the nearest car's scene and set its body path)" }
New-Item -ItemType Directory -Force $Out | Out-Null

Stage "refine" {
    try {                                                    # available = free + standby cache (the performance-counter classes are broken on this machine)
        Add-Type -AssemblyName Microsoft.VisualBasic
        $free = (New-Object Microsoft.VisualBasic.Devices.ComputerInfo).AvailablePhysicalMemory / 1MB
    } catch { $free = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB }
    if ($free -lt 5000 -and -not $Force) { Fail ("only {0:n0} MB of RAM available, refine needs about 5000 (close other apps, or use -Force)" -f $free) }
    $log = Join-Path $Out "refine.txt"
    $code = Run $Blender @("--background", "--python", "scratch\refine_car.py", "--", $Config, "--out-dir", $Out) $log
    $text = Get-Content $log -Raw
    if ($code -ne 0) { Fail "blender exit $code, see $log" }
    if ($text -match "wheel cut failed") { Fail "the wheel cut failed, see $log" }
    if ($text -notmatch "exported") { Fail "no body GLB was exported, see $log" }
    if ($text -notmatch "FINAL tris (\d+)") { Fail "no FINAL line in $log" }
    $tris = [int]$Matches[1]
    if ($tris -lt 80000 -or $tris -gt 120000) { Fail "$tris triangles, outside 80k-120k" }
    if ($text -notmatch "bbox \[\s*-?[\d.]+\s+-?[\d.]+\s+(-?[\d.]+)\s*\]") { Fail "no bbox in the FINAL line" }
    if ([double]$Matches[1] -lt 0.049) { Fail "lowest body point z $($Matches[1]) is below the ground clamp" }
    ($text -split "`n" | Where-Object { $_ -match "fender lift applied|wheel cut:|ground clamp|FINAL tris" }) | ForEach-Object { Write-Host ("    " + ($_ -replace "^RC +[\d.]+s ", "").Trim()) }
}

Stage "install" {
    $dest = Join-Path $Project (Split-Path $cfg.body_glb -Parent)
    $tex = Join-Path $Project $cfg.texture_dir
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = Join-Path $Project "temp\backup_${Car}_$stamp"
    New-Item -ItemType Directory -Force $backup | Out-Null
    foreach ($f in @((Join-Path $Project $cfg.body_glb), (Join-Path $Project ($cfg.body_glb -replace "_body\.glb$", "_full.glb"))) + (Get-ChildItem $tex -Filter *.png | ForEach-Object { $_.FullName })) {
        if (Test-Path $f) { Copy-Item $f $backup }
    }
    foreach ($f in "base_color.png", "normal.png", "orm.png") { if (-not (Test-Path (Join-Path $Out $f))) { Fail "$f was not written to $Out" } }
    Copy-Item (Join-Path $Out (Split-Path $cfg.body_glb -Leaf)) (Join-Path $Project $cfg.body_glb) -Force
    foreach ($f in "base_color.png", "normal.png", "orm.png") { Copy-Item (Join-Path $Out $f) $tex -Force }
    Write-Host "    installed; the previous files are in $backup"
}

Stage "import" {
    $code = Run $Godot @("--headless", "--path", ".", "--import") (Join-Path $Out "import.txt")
    if ($code -ne 0) { Fail "godot import exit $code" }
}

Stage "gate" {
    $log = Join-Path $Out "gate.txt"
    $code = Run $Godot @("--headless", "--path", ".", "-s", "scratch/fit_cars.gd", "--", "--apply", $Car) $log
    $text = Get-Content $log -Raw
    ($text -split "`n" | Where-Object { $_ -match "^\s+[FR][LR] |floor y|proposed|applied|FIT GATE" -and $_ -notmatch "^(porsche|audi)" }) | ForEach-Object { Write-Host ("    " + ($_ -replace "\(sock x [\d.]+\) ", "").TrimEnd()) }
    if ($code -ne 0) { Fail "the fit gate failed, see $log" }
    if ($text -match "applied: (\d+) socket" -and [int]$Matches[1] -gt 0) { Write-Host "    socket x changed: the full GLB is rebuilt next" }
}

Stage "full" {
    $glb = Join-Path $Project ($cfg.body_glb -replace "_body\.glb$", "_full.glb")
    $code = Run $Blender @("--background", "--python", "scratch\build_full_car.py", "--", "scenes\car\${Car}_chassis.tscn", $glb) (Join-Path $Out "full.txt")
    if ($code -ne 0 -or -not ((Get-Content (Join-Path $Out "full.txt") -Raw) -match "FULLCAR exported")) { Fail "build_full_car.py failed, see $Out\full.txt" }
    $code = Run $Godot @("--headless", "--path", ".", "--import") (Join-Path $Out "import2.txt")
    if ($code -ne 0) { Fail "godot import exit $code" }
}

Stage "test" {
    foreach ($t in "tests/test_${Car}_chassis.gd", "tests/test_modular_car.gd") {
        if (-not (Test-Path (Join-Path $Project $t))) { Fail "$t is missing" }
        $code = Run $Godot @("--headless", "--path", ".", "-s", $t) (Join-Path $Out ((Split-Path $t -Leaf) + ".txt"))
        $sum = (Get-Content (Join-Path $Out ((Split-Path $t -Leaf) + ".txt")) | Where-Object { $_ -match "assertions, |: PASS|FAILURES" } | Select-Object -Last 1)
        Write-Host ("    {0}: exit {1} {2}" -f (Split-Path $t -Leaf), $code, $sum)
        if ($code -ne 0) { Fail "$t failed, see $Out" }
    }
}

Stage "review" {
    if ($NoReview) { Write-Host "    skipped (-NoReview)"; return }
    $code = Run $Godot @("--rendering-driver", "d3d12", "--resolution", "1280x800", "--path", ".", "-s", "scratch/capture_wheel_review.gd", "--", $Car) (Join-Path $Out "review.txt")
    if ($code -ne 0) { Fail "the review render failed, see $Out\review.txt" }
    Write-Host "    renders: temp\wheel_review\${Car}_*.png  <- look at ${Car}_fr_high.png and ${Car}_rr_high.png before calling the car done"
}

Write-Host "make_car $Car : all requested stages passed."
