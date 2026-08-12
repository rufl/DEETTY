param(
    [switch]$AutomatedHost,
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $PSScriptRoot 'noctty.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "Missing packaged executable: $exe"
}

$selfTest = Start-Process -FilePath $exe -ArgumentList '--self-test' -Wait -PassThru
if ($selfTest.ExitCode -ne 0) {
    throw "NOCTTY Windows VT self-test failed with exit code $($selfTest.ExitCode)."
}

$os = [System.Environment]::OSVersion.VersionString
Write-Host "windows_smoke self_test=true os='$os'"
$logDirectory = Join-Path $env:LOCALAPPDATA 'NOCTTY\logs'

if ($AutomatedHost) {
    $shellBefore = $env:NOCTTY_WINDOWS_SHELL
    $smokeBefore = $env:NOCTTY_WINDOWS_HOST_SMOKE
    try {
        $env:NOCTTY_WINDOWS_SHELL = 'cmd.exe /d /c "echo NOCTTY_WINDOWS_HOST_OK"'
        $env:NOCTTY_WINDOWS_HOST_SMOKE = '1'
        $automatedStartedAt = Get-Date
        $automated = Start-Process -FilePath $exe -Wait -PassThru
    }
    finally {
        $env:NOCTTY_WINDOWS_SHELL = $shellBefore
        $env:NOCTTY_WINDOWS_HOST_SMOKE = $smokeBefore
    }
    if ($automated.ExitCode -ne 0) {
        throw "Automated ConPTY/GDI host smoke failed with exit code $($automated.ExitCode)."
    }
    $automatedLog = Get-ChildItem -LiteralPath $logDirectory -Filter 'noctty-*.log' -File |
        Where-Object { $_.LastWriteTime -ge $automatedStartedAt } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $automatedLog) {
        throw "The automated host smoke created no log under $logDirectory."
    }
    $automatedText = Get-Content -LiteralPath $automatedLog.FullName -Raw
    if ($automatedText -notmatch 'windows_host_smoke conpty=true vt=true gdi=true clean_exit=true') {
        throw 'The automated host log is missing its ConPTY/VT/GDI acceptance marker.'
    }
    if ($automatedText -notmatch 'windows_exit clean=true') {
        throw 'The automated host log is missing clean native-host teardown.'
    }
    Write-Host "windows_smoke self_test=true automated_host=true conpty=true vt=true gdi=true clean_exit=true log='$($automatedLog.FullName)' physical_input=false"
}

if (-not $Interactive) {
    Write-Host 'Run again with -Interactive for the physical input/resize checklist.'
    exit 0
}

$startedAt = Get-Date
$process = Start-Process -FilePath $exe -PassThru

Write-Host ''
Write-Host 'Physical checklist:'
Write-Host '  1. Confirm PowerShell or cmd renders a prompt.'
Write-Host '  2. Type: Write-Output "NOCTTY_WINDOWS_OK" (PowerShell) or echo NOCTTY_WINDOWS_OK (cmd).'
Write-Host '  3. Resize the window narrower and wider; confirm retained text reflows/redraws.'
Write-Host '  4. Test arrow keys, Unicode input, Ctrl+Shift+C, and Ctrl+Shift+V.'
Write-Host '  5. Scroll output with the mouse wheel.'
Write-Host '  6. Close the NOCTTY window normally.'
Write-Host ''
Read-Host 'Press Enter here after closing the NOCTTY window'

$process.Refresh()
if (-not $process.HasExited) {
    Write-Warning 'NOCTTY is still running; close it normally before accepting this smoke.'
    exit 2
}

$log = Get-ChildItem -LiteralPath $logDirectory -Filter 'noctty-*.log' -File |
    Where-Object { $_.LastWriteTime -ge $startedAt } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($null -eq $log) {
    throw "No launch log was created under $logDirectory."
}

$logText = Get-Content -LiteralPath $log.FullName -Raw
if ($logText -notmatch 'windows_launch .*conpty=true') {
    throw 'The launch receipt is missing the ConPTY marker.'
}
if ($logText -notmatch 'shell_spawned') {
    throw 'The launch receipt does not show a spawned shell.'
}
if ($logText -notmatch 'windows_exit clean=true') {
    throw 'The launch receipt does not show clean native-host teardown.'
}

Write-Host "windows_smoke self_test=true interactive=true conpty=true shell=true clean_exit=true log='$($log.FullName)' physical_operator_acceptance=pending_manual_answers"
Write-Host 'Record the checklist observations separately; this script cannot infer visual/input acceptance.'
