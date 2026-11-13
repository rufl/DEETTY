param(
    [switch]$AutomatedHost,
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $PSScriptRoot 'dintty.exe'
$nocted = Join-Path $PSScriptRoot 'nocted.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "Missing packaged executable: $exe"
}
if (-not (Test-Path -LiteralPath $nocted -PathType Leaf)) {
    throw "Missing packaged executable: $nocted"
}

$selfTest = Start-Process -FilePath $exe -ArgumentList '--self-test' -Wait -PassThru
if ($selfTest.ExitCode -ne 0) {
    throw "DINTTY Windows VT/input self-test failed with exit code $($selfTest.ExitCode)."
}
$noctedSelfTest = Start-Process -FilePath $nocted -ArgumentList '--self-test' -Wait -PassThru
if ($noctedSelfTest.ExitCode -ne 0) {
    throw "NoctEd Windows document self-test failed with exit code $($noctedSelfTest.ExitCode)."
}

$os = [System.Environment]::OSVersion.VersionString
Write-Host "windows_smoke self_test=true nocted_self_test=true os='$os'"
$logDirectory = Join-Path $env:LOCALAPPDATA 'DINTTY\logs'

if ($AutomatedHost) {
    $shellBefore = $env:DINTTY_WINDOWS_SHELL
    $smokeBefore = $env:DINTTY_WINDOWS_HOST_SMOKE
    try {
        $env:DINTTY_WINDOWS_SHELL = 'cmd.exe /d /c "echo DINTTY_WINDOWS_HOST_OK"'
        $env:DINTTY_WINDOWS_HOST_SMOKE = '1'
        $automatedStartedAt = Get-Date
        $automated = Start-Process -FilePath $exe -Wait -PassThru
    }
    finally {
        $env:DINTTY_WINDOWS_SHELL = $shellBefore
        $env:DINTTY_WINDOWS_HOST_SMOKE = $smokeBefore
    }
    if ($automated.ExitCode -ne 0) {
        throw "Automated ConPTY/GDI host smoke failed with exit code $($automated.ExitCode)."
    }
    $automatedLog = Get-ChildItem -LiteralPath $logDirectory -Filter 'dintty-*.log' -File |
        Where-Object { $_.LastWriteTime -ge $automatedStartedAt } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $automatedLog) {
        throw "The automated host smoke created no log under $logDirectory."
    }
    $automatedText = Get-Content -LiteralPath $automatedLog.FullName -Raw
    if ($automatedText -notmatch 'windows_host_smoke conpty=true vt=true gdi=true settings_menu=true preferences=true mouse_input=true coordinates=true selection=true clipboard=true clean_exit=true') {
        throw 'The automated host log is missing its ConPTY/VT/GDI/settings/input acceptance marker.'
    }
    if ($automatedText -notmatch 'windows_exit clean=true') {
        throw 'The automated host log is missing clean native-host teardown.'
    }
    Write-Host "windows_smoke self_test=true nocted_self_test=true automated_host=true conpty=true vt=true gdi=true settings_menu=true preferences=true mouse_input=true coordinates=true selection=true clipboard=true clean_exit=true log='$($automatedLog.FullName)' physical_input=false"
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
Write-Host '  2. Open Settings; switch theme and font size, restart, and confirm both persist.'
Write-Host '     Check DINTTY Dark, Paseo Black Zinc, and Windows high-contrast colors, including ANSI output. Enter exact font size 23, test increase/decrease/reset and 8/32 boundaries; invalid sizes must remain in the dialog and Cancel must preserve the prior size.'
Write-Host '     Import a .dinttythemes library through a Unicode path; select each custom theme and restart. Check foreground/background, ANSI colors, and block cursor. Export and re-import, cancel each dialog, decline replacement, reject a corrupt file, and verify failed writes preserve the prior library.'
Write-Host '  3. Select Command Prompt as the launch profile, open a tab, and confirm cmd starts.'
Write-Host '     Open Manage Profiles; create and rename a Unicode-named profile with an executable and working directory containing spaces, raw arguments, environment overrides, and scrollback. Save/restart, select it, and confirm a new tab and split receive every field while existing sessions remain unchanged.'
Write-Host '     Cancel dirty edits and deletion; reject duplicate/built-in names, invalid paths, and oversized fields. Delete the selected custom and confirm PowerShell fallback. Test failed persistence, corrupt profile state, custom launch failure without shell substitution, inherited environment preservation, and operator-override precedence.'
Write-Host '  4. Use Workspace > New Tab, Split Down, Split Left, Next Pane, and Next Tab; confirm Ctrl+Tab/Ctrl+Shift+Tab agree. Save the layout, alter it, then restore it.'
Write-Host '     Click each tab and use Workspace > Focus Tab Strip for keyboard selection; terminal F2/F6 must still reach the shell/TUI when the terminal has focus.'
Write-Host '     Rename a tab with Unicode text, cancel a second rename, move it left/right, then close a different tab. Confirm the selected shell and each tab''s focused split remain unchanged.'
Write-Host '     Drag tabs in both directions, including duplicate titles. Check insertion feedback, Escape/capture-loss cancellation, normal click selection, and no pane/session replacement. Remote tab dragging must remain disabled.'
Write-Host '     Save and restore the layout: custom names/order return with replacement shells. An empty rename restores the automatic label; oversized/control-character names are rejected.'
Write-Host '     Drag vertical and horizontal dividers in nested splits: a preview follows the pointer, release commits, and Escape or capture loss cancels without changing the saved ratio. Move between DPI scales; terminal clicks must not leak through the divider band.'
Write-Host '     Use Wider/Narrower/Taller/Shorter on panes on both sides, then Equalize Splits. Save unequal ratios and restore/restart; ratios return with replacement shells, while resizing itself never replaces sessions.'
Write-Host '  5. Type: Write-Output "DINTTY_WINDOWS_OK" (PowerShell) or echo DINTTY_WINDOWS_OK (cmd).'
Write-Host '  6. Resize the window narrower and wider; confirm retained text reflows/redraws.'
Write-Host '     Confirm the tab strip stays above terminal text at different DPI/font sizes; clicks, selection, application mouse input, and the last terminal row stay aligned below it.'
Write-Host '  7. Test arrow keys, Unicode input, Ctrl+Shift+V, and Shift+Insert.'
Write-Host '  8. Drag-select across lines; test Terminal > Copy and Paste alongside shortcuts, including wide/combining Unicode. Terminal > Clear Screen must send Ctrl+L only to the focused pane; the shell controls redraw.'
Write-Host '  9. In an installed mouse-aware TUI, verify click, drag/motion, and wheel input; hold Shift and confirm left drag selects locally.'
Write-Host ' 10. Open NoctEd from the menu; open, edit, find, and save a UTF-8 file; open a folder; restart and confirm tabs/project restore.'
Write-Host '     Use Workspace > Close Pane and Close Tab; confirm only the selected target closes and the final session is protected.'
Write-Host '     In a remote viewer, select tabs in the strip; confirm host names/order update and local rename/reorder/mutation items are disabled. Denied Clear Screen/Paste must show an error.'
Write-Host '     Remote divider dragging and resize/reset commands must be disabled and rejected; local appearance controls remain available.'
Write-Host ' 11. Close the DINTTY window normally.'
Write-Host ''
Read-Host 'Press Enter here after closing the DINTTY window'

$process.Refresh()
if (-not $process.HasExited) {
    Write-Warning 'DINTTY is still running; close it normally before accepting this smoke.'
    exit 2
}

$log = Get-ChildItem -LiteralPath $logDirectory -Filter 'dintty-*.log' -File |
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

Write-Host "windows_smoke self_test=true nocted_self_test=true interactive=true conpty=true shell=true clean_exit=true log='$($log.FullName)' physical_operator_acceptance=pending_manual_answers"
Write-Host 'Record the checklist observations separately; this script cannot infer visual/input/editor acceptance.'
