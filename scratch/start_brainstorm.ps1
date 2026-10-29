$SessionId = [System.Guid]::NewGuid().ToString()
$SessionDir = Join-Path (Get-Location) ".superpowers\brainstorm\$SessionId"
New-Item -ItemType Directory -Force -Path (Join-Path $SessionDir "content") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $SessionDir "state") | Out-Null

$env:BRAINSTORM_DIR = $SessionDir
$env:BRAINSTORM_HOST = "127.0.0.1"
$env:BRAINSTORM_URL_HOST = "localhost"
$env:BRAINSTORM_OWNER_PID = $PID

Write-Host "SESSION_DIR=$SessionDir"
node "C:\Users\Lee\.gemini\config\plugins\superpowers\skills\brainstorming\scripts\server.cjs"
