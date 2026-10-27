$tests = Get-ChildItem tests\test_*.gd
$results = @()
$totalFailed = 0

foreach ($t in $tests) {
    $cmdArgs = @("--headless", "--path", ".", "-s", "res://tests/$($t.Name)")
    if ($t.Name -eq "test_race_world.gd") {
        $cmdArgs = @("--headless", "--fixed-fps", "60", "--path", ".", "-s", "res://tests/$($t.Name)")
    } elseif ($t.Name -in @("test_audio_and_race_weekend.gd", "test_race_weekend_and_physics.gd")) {
        $cmdArgs += @("--", "--skip-legacy")
    }

    $output = & godot @cmdArgs 2>&1
    $exitCode = $LASTEXITCODE
    $failedMatches = $output | Select-String -Pattern "\[FAIL\]" -CaseSensitive
    $failSummaryMatches = $output | Select-String -Pattern "([1-9]\d* failure|[1-9]\d* FAIL)" -CaseSensitive
    
    $isFail = ($exitCode -ne 0) -or ($failedMatches.Count -gt 0) -or ($failSummaryMatches.Count -gt 0)
    $passCount = ($output | Select-String -Pattern "\[PASS\]").Count

    if ($isFail) {
        $totalFailed++
        Write-Host "FAILED: $($t.Name) (Exit: $exitCode, FailedLines: $($failedMatches.Count))" -ForegroundColor Red
        $results += [PSCustomObject]@{ Test = $t.Name; Status = "FAIL"; Passes = $passCount; ExitCode = $exitCode }
    } else {
        Write-Host "PASSED: $($t.Name) ($passCount passes)" -ForegroundColor Green
        $results += [PSCustomObject]@{ Test = $t.Name; Status = "PASS"; Passes = $passCount; ExitCode = $exitCode }
    }
}
Write-Host "`n================== SUMMARY =================="
$results | Format-Table -AutoSize
Write-Host "Total: $($tests.Count), Passed: $($tests.Count - $totalFailed), Failed: $totalFailed"
