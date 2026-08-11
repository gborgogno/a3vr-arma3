param(
    [switch]$Windowed,
    [string]$GameDirectory = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($GameDirectory)) {
    $Candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:ARMA3_DIR)) {
        $Candidates += $env:ARMA3_DIR
    }
    $Candidates += @(
        "D:\SteamLibrary\steamapps\common\Arma 3",
        "C:\Program Files (x86)\Steam\steamapps\common\Arma 3",
        "C:\Program Files\Steam\steamapps\common\Arma 3"
    )
    $GameDirectory = $Candidates | Where-Object {
        Test-Path -LiteralPath (Join-Path $_ "arma3_x64.exe")
    } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($GameDirectory)) {
    throw "Arma 3 was not found. Pass -GameDirectory or set ARMA3_DIR."
}
$Game = Join-Path $GameDirectory "arma3_x64.exe"
$ModDirectory = Split-Path -Parent $PSScriptRoot
$ModName = Split-Path -Leaf $ModDirectory
$Runtime = Join-Path $ModDirectory "A3VRRuntime_v23.exe"

if (-not (Test-Path -LiteralPath $Game)) { throw "Arma 3 was not found at $Game" }
if (-not (Test-Path -LiteralPath $Runtime)) { throw "A3VR runtime v23 was not found at $Runtime" }
if (Get-Process arma3_x64 -ErrorAction SilentlyContinue) {
    throw "Close the existing Arma 3 process before starting A3VR."
}
if (Get-Process -Name "A3VRRuntime_v*" -ErrorAction SilentlyContinue) {
    throw "An A3VR runtime is already running. Close it before retrying."
}

$env:A3VR_STEREO_MODE = "mono"
$env:A3VR_CONTROLLER_AIM = "1"
$env:A3VR_CONTROLLER_COUNTS_PER_RADIAN = "900"
$env:A3VR_CONTROLLER_BUTTONS = "1"
$env:A3VR_CONTROLLER_STICK_THRESHOLD = "0.25"
$RuntimeProcess = Start-Process -FilePath $Runtime -WorkingDirectory $ModDirectory `
    -WindowStyle Hidden -PassThru
try {
    Start-Sleep -Milliseconds 1200
    if ($RuntimeProcess.HasExited) {
        throw "A3VRRuntime_v23 exited before Arma started."
    }
    $GameArguments = @("-noSplash", "-skipIntro", "-mod=$ModName")
    if ($Windowed) { $GameArguments += "-window" }
    Start-Process -FilePath $Game -WorkingDirectory $GameDirectory `
        -ArgumentList $GameArguments | Out-Null
} catch {
    if (-not $RuntimeProcess.HasExited) {
        Stop-Process -Id $RuntimeProcess.Id -Force -ErrorAction SilentlyContinue
    }
    throw
}
