param(
    [Parameter(Mandatory = $true)]
    [string]$RunDirectory
)

$ErrorActionPreference = "Stop"
$gui = Join-Path $RunDirectory "fcstm-gui.exe"
$report = Join-Path $RunDirectory "fcstm-gui-acceptance.json"
$artifactDirectory = Join-Path $RunDirectory "fcstm-gui-acceptance-artifacts"
$stdout = Join-Path $RunDirectory "fcstm-gui-acceptance.stdout.log"
$stderr = Join-Path $RunDirectory "fcstm-gui-acceptance.stderr.log"
$session = Join-Path $RunDirectory "gui-session.txt"
$before = Join-Path $RunDirectory "desktop-before.png"
$beforeMetadata = Join-Path $RunDirectory "desktop-before.txt"
$visible = Join-Path $RunDirectory "desktop-gui-visible.png"
$visibleMetadata = Join-Path $RunDirectory "desktop-gui-visible.txt"
$after = Join-Path $RunDirectory "desktop-after.png"
$afterMetadata = Join-Path $RunDirectory "desktop-after.txt"
$timeoutSeconds = 900

New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null
"user=$env:USERNAME" | Set-Content -Path $session -Encoding ASCII
"qt_qpa_platform=$env:QT_QPA_PLATFORM" | Add-Content -Path $session -Encoding ASCII
"acceptance_timeout_seconds=$timeoutSeconds" | Add-Content -Path $session -Encoding ASCII

& (Join-Path $RunDirectory "capture-desktop.ps1") -Path $before -MetadataPath $beforeMetadata

$arguments = @(
    "--acceptance-check",
    "--viewport", "1280x720",
    "--json-report", $report,
    "--artifact-dir", $artifactDirectory
)
$process = Start-Process -FilePath $gui -ArgumentList $arguments -WorkingDirectory $RunDirectory `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
"process_id=$($process.Id)" | Add-Content -Path $session -Encoding ASCII
"session_id=$($process.SessionId)" | Add-Content -Path $session -Encoding ASCII

$windowProcess = $null
for ($attempt = 0; $attempt -lt 180; $attempt++) {
    $windowProcess = Get-Process -Name "fcstm-gui" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -ne "" } |
        Select-Object -First 1
    if ($null -ne $windowProcess) {
        break
    }
    Start-Sleep -Seconds 1
}

if ($null -eq $windowProcess) {
    "window_visible=false" | Add-Content -Path $session -Encoding ASCII
    $process.WaitForExit()
    exit 20
}

"window_visible=true" | Add-Content -Path $session -Encoding ASCII
"window_process_id=$($windowProcess.Id)" | Add-Content -Path $session -Encoding ASCII
"window_handle=$($windowProcess.MainWindowHandle)" | Add-Content -Path $session -Encoding ASCII
"window_title=$($windowProcess.MainWindowTitle)" | Add-Content -Path $session -Encoding ASCII
& cmd.exe /c "echo GUI_VISIBLE>COM1"
Start-Sleep -Seconds 10
& (Join-Path $RunDirectory "capture-desktop.ps1") -Path $visible -MetadataPath $visibleMetadata

$completed = $process.WaitForExit($timeoutSeconds * 1000)
if (-not $completed) {
    "acceptance_timeout=true" | Add-Content -Path $session -Encoding ASCII
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    exit 21
}
$process.Refresh()
$exitCode = $process.ExitCode
"process_has_exited=$($process.HasExited)" | Add-Content -Path $session -Encoding ASCII
if ($null -eq $exitCode -or "$exitCode" -eq "") {
    # Windows PowerShell 2 can expose a completed Start-Process object without
    # materializing ExitCode; the acceptance JSON is the authoritative result.
    "process_exit_code_source=acceptance_report" | Add-Content -Path $session -Encoding ASCII
    $exitCode = 1
    if ((Test-Path $report) -and (Select-String -Path $report -SimpleMatch '"status": "passed"' -Quiet)) {
        $exitCode = 0
    }
}
"acceptance_exit_code=$exitCode" | Add-Content -Path $session -Encoding ASCII
& (Join-Path $RunDirectory "capture-desktop.ps1") -Path $after -MetadataPath $afterMetadata
& cmd.exe /c "echo GUI_AFTER>COM1"

exit $exitCode
