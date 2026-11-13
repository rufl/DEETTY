[CmdletBinding()]
param(
    [string]$InstallerPath = (Join-Path $PSScriptRoot "deetty-windows-x86_64-dogfood-setup.exe"),
    [string]$ChecksumPath = "",
    [switch]$Silent,
    [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
if (-not $ChecksumPath) {
    $ChecksumPath = "$installer.sha256"
}
$checksum = (Resolve-Path -LiteralPath $ChecksumPath).Path

$checksumLine = (Get-Content -LiteralPath $checksum -Raw).Trim()
$checksumMatch = [regex]::Match($checksumLine, '^([0-9a-fA-F]{64})\s+\*?([^\r\n]+)$')
if (-not $checksumMatch.Success) {
    throw "Invalid SHA-256 sidecar: $checksum"
}
if ($checksumMatch.Groups[2].Value -ne (Split-Path -Leaf $installer)) {
    throw "Checksum sidecar names a different installer: $($checksumMatch.Groups[2].Value)"
}
$expectedSha256 = $checksumMatch.Groups[1].Value.ToLowerInvariant()
$actualSha256 = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
    throw "Installer SHA-256 mismatch: expected $expectedSha256, got $actualSha256"
}

Write-Output "windows_dogfood_verify installer=$installer sha256=$actualSha256 valid=true signed=false"
if ($VerifyOnly) {
    return
}
if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw "Installation requires Windows 10 version 1809 or newer, or Windows 11"
}
$windowsBuild = [System.Environment]::OSVersion.Version.Build
if ($windowsBuild -lt 17763) {
    throw "DEETTY requires Windows build 17763 or newer; found $windowsBuild"
}
$running = @(Get-Process -Name @('deetty', 'nocted') -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    throw "Close every running DEETTY and NoctEd process before installing dogfood"
}


$start = @{
    FilePath = $installer
    Wait = $true
    PassThru = $true
}
if ($Silent) {
    $start.ArgumentList = @('/S')
}
$process = Start-Process @start
if ($process.ExitCode -ne 0) {
    throw "DEETTY installer exited with status $($process.ExitCode)"
}

$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DEETTY'
$installed = Get-ItemProperty -LiteralPath $uninstallKey -ErrorAction Stop
$installDirectory = [string]$installed.InstallLocation
if (-not $installDirectory) {
    throw "DEETTY installer did not record its install directory"
}
$deetty = Join-Path $installDirectory 'deetty.exe'
$nocted = Join-Path $installDirectory 'nocted.exe'
$buildInfo = Join-Path $installDirectory 'BUILD-INFO.txt'
foreach ($path in @($deetty, $nocted, $buildInfo)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Installed payload is incomplete: $path"
    }
}
if (-not (Select-String -LiteralPath $buildInfo -Pattern '^package=deetty$' -Quiet)) {
    throw "Installed BUILD-INFO.txt does not identify DEETTY"
}

foreach ($selfTest in @($deetty, $nocted)) {
    $test = Start-Process -FilePath $selfTest -ArgumentList @('--self-test') -Wait -PassThru
    if ($test.ExitCode -ne 0) {
        throw "Installed self-test failed: $selfTest exited with status $($test.ExitCode)"
    }
}

$stateDirectory = Join-Path $env:LOCALAPPDATA 'DEETTY'
New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
$receipt = Join-Path $stateDirectory 'dogfood-install.receipt'
$temporaryReceipt = "$receipt.new.$PID"
$receiptLines = @(
    'receipt_version=1',
    "install_timestamp=$([DateTimeOffset]::UtcNow.ToString('o'))",
    "installer_sha256=$actualSha256",
    "installer_signed=false",
    "display_version=$([string]$installed.DisplayVersion)",
    "install_directory=$installDirectory",
    "deetty_sha256=$((Get-FileHash -LiteralPath $deetty -Algorithm SHA256).Hash.ToLowerInvariant())",
    "nocted_sha256=$((Get-FileHash -LiteralPath $nocted -Algorithm SHA256).Hash.ToLowerInvariant())",
    'deetty_self_test=true',
    'nocted_self_test=true',
    'physical_windows_validation=false'
)
[System.IO.File]::WriteAllLines($temporaryReceipt, $receiptLines, [System.Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temporaryReceipt -Destination $receipt -Force

Write-Output "windows_dogfood_install directory=$installDirectory self_tests=true receipt=$receipt physical_windows_validation=false"
