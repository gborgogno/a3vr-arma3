param(
    [switch]$Windowed,
    [string]$GameDirectory = "",
    [switch]$UseArmaLauncher,
    [switch]$FastStart,
    [string]$AdditionalMods = ""
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
$Launcher = Join-Path $GameDirectory "arma3launcher.exe"
$ModDirectory = Split-Path -Parent $PSScriptRoot
$ModName = Split-Path -Leaf $ModDirectory
$Runtime = Join-Path $ModDirectory "A3VRRuntime_v30.exe"

if (-not (Test-Path -LiteralPath $Game)) { throw "Arma 3 was not found at $Game" }
if ($UseArmaLauncher -and -not (Test-Path -LiteralPath $Launcher)) {
    throw "Arma 3 Launcher was not found at $Launcher"
}
if ($UseArmaLauncher -and -not [string]::IsNullOrWhiteSpace($AdditionalMods)) {
    throw "Use either -UseArmaLauncher or -AdditionalMods, not both."
}
if (-not (Test-Path -LiteralPath $Runtime)) { throw "A3VR runtime v30 was not found at $Runtime" }
if (Get-Process arma3_x64 -ErrorAction SilentlyContinue) {
    throw "Close the existing Arma 3 process before starting A3VR."
}
if (Get-Process -Name "A3VRRuntime_v*" -ErrorAction SilentlyContinue) {
    throw "An A3VR runtime is already running. Close it before retrying."
}

$env:A3VR_STEREO_MODE = "mono"
$env:A3VR_MONO_SCREEN_WIDTH = "13.0"
$env:A3VR_MONO_SCREEN_DISTANCE = "5.0"
$env:A3VR_CONTROLLER_AIM = "1"
$env:A3VR_CONTROLLER_COUNTS_PER_RADIAN = "650"
$env:A3VR_HEAD_ROTATION_GAIN = "0.48"
$env:A3VR_CONTROLLER_BUTTONS = "1"
$env:A3VR_PROXY_WEAPON = "1"
$env:A3VR_CONTROLLER_STICK_THRESHOLD = "0.25"
$env:A3VR_SMOOTH_TURN = "1"
$env:A3VR_SMOOTH_TURN_COUNTS_PER_SECOND = "420"
$RuntimeProcess = Start-Process -FilePath $Runtime -WorkingDirectory $ModDirectory `
    -WindowStyle Hidden -PassThru
try {
    Start-Sleep -Milliseconds 1200
    if ($RuntimeProcess.HasExited) {
        throw "A3VRRuntime_v30 exited before Arma started."
    }
    if ($UseArmaLauncher) {
        $LauncherProcess = Start-Process -FilePath $Launcher `
            -WorkingDirectory $GameDirectory -PassThru
        while (-not $LauncherProcess.HasExited) {
            if (Get-Process arma3_x64 -ErrorAction SilentlyContinue) {
                return
            }
            Start-Sleep -Milliseconds 500
        }
        if (-not (Get-Process arma3_x64 -ErrorAction SilentlyContinue)) {
            throw "Arma 3 Launcher closed without starting the game."
        }
    } else {
        $ModList = @($ModName)
        if (-not [string]::IsNullOrWhiteSpace($AdditionalMods)) {
            $ParsedMods = @($AdditionalMods.Split(';') | ForEach-Object {
                $_.Trim()
            } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $ModList += $ParsedMods
        }
        $GameArguments = @("-mod=$($ModList -join ';')")
        if ($FastStart) { $GameArguments = @("-noSplash", "-skipIntro") + $GameArguments }
        if ($Windowed) { $GameArguments += "-window" }
        Start-Process -FilePath $Game -WorkingDirectory $GameDirectory `
            -ArgumentList $GameArguments | Out-Null
    }
} catch {
    if (-not $RuntimeProcess.HasExited) {
        Stop-Process -Id $RuntimeProcess.Id -Force -ErrorAction SilentlyContinue
    }
    throw
}
