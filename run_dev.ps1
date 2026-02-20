$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDir = Join-Path $repoRoot "backend\server"
$frontendDir = Join-Path $repoRoot "frontend"
$backendProcess = $null

try {
    if (Get-Command adb -ErrorAction SilentlyContinue) {
        adb reverse tcp:8000 tcp:8000 | Out-Null
        Write-Host "adb reverse configured: device 127.0.0.1:8000 -> host 127.0.0.1:8000"
    } else {
        Write-Warning "adb not found. USB Android reverse tunnel was not configured."
    }

    Push-Location $backendDir
    $backendProcess = Start-Process -FilePath python -ArgumentList "manage.py", "runserver", "127.0.0.1:8000" -PassThru
    Pop-Location

    Start-Sleep -Seconds 2

    Push-Location $frontendDir
    flutter run
    Pop-Location
}
finally {
    if ($backendProcess -and !$backendProcess.HasExited) {
        Stop-Process -Id $backendProcess.Id
    }
}
