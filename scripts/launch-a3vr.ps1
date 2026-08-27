param(
    [switch]$Windowed,
    [string]$GameDirectory = "",
    [switch]$UseArmaLauncher,
    [switch]$FastStart
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
$Runtime = Join-Path $ModDirectory "A3VRRuntime_v31.exe"

if (-not (Test-Path -LiteralPath $Game)) { throw "Arma 3 was not found at $Game" }
if ($UseArmaLauncher -and -not (Test-Path -LiteralPath $Launcher)) {
    throw "Arma 3 Launcher was not found at $Launcher"
}
if (-not (Test-Path -LiteralPath $Runtime)) { throw "A3VR runtime v31 was not found at $Runtime" }
if (Get-Process arma3_x64 -ErrorAction SilentlyContinue) {
    throw "Close the existing Arma 3 process before starting A3VR."
}

# Local updates can be staged while Arma still has its PBO and extension DLL
# open. Apply the complete native/addon set atomically after the game closes so
# one test run never mixes files from two builds.
$StagedRelativePaths = @(
    "addons\a3vr_hybrid.pbo",
    "A3VRHybridCore_x64.dll",
    "A3VRRuntime_v31.exe"
)
foreach ($RelativePath in $StagedRelativePaths) {
    $ActiveFile = Join-Path $ModDirectory $RelativePath
    $PendingFile = $ActiveFile + ".pending"
    if (-not (Test-Path -LiteralPath $PendingFile -PathType Leaf)) { continue }
    $PendingHash = (Get-FileHash -LiteralPath $PendingFile `
        -Algorithm SHA256).Hash
    if (Test-Path -LiteralPath $ActiveFile -PathType Leaf) {
        $PreviousFile = $ActiveFile + ".previous"
        [System.IO.File]::Replace(
            $PendingFile, $ActiveFile, $PreviousFile, $true)
    } else {
        Move-Item -LiteralPath $PendingFile -Destination $ActiveFile
    }
    $InstalledHash = (Get-FileHash -LiteralPath $ActiveFile `
        -Algorithm SHA256).Hash
    if ($InstalledHash -ne $PendingHash) {
        throw "The staged A3VR file failed its post-install hash check: $RelativePath"
    }
    Write-Host "Applied staged A3VR file: $RelativePath ($InstalledHash)"
}

if (Get-Process -Name "A3VRRuntime_v*" -ErrorAction SilentlyContinue) {
    throw "An A3VR runtime is already running. Close it before retrying."
}

$ProfileTuner = Join-Path $PSScriptRoot "set-a3vr-profile.ps1"
if (Test-Path -LiteralPath $ProfileTuner) {
    & $ProfileTuner -GraphicsPreset Stereo
}

$env:A3VR_STEREO_MODE = "sbs"
$env:A3VR_VISUAL_PROFILE = "stereo-rtt-v1"
$env:A3VR_UI_SCREEN_WIDTH = "5.0"
$env:A3VR_CONTROLLER_AIM = "1"
$env:A3VR_CONTROLLER_COUNTS_PER_RADIAN = "900"
$env:A3VR_HEAD_ROTATION_GAIN = "1.0"
$env:A3VR_BODY_RECESS_MM = "140"
$env:A3VR_CONTROLLER_BUTTONS = "1"
$env:A3VR_PROXY_WEAPON = "0"
$env:A3VR_CONTROLLER_STICK_THRESHOLD = "0.25"
$env:A3VR_SMOOTH_TURN = "1"
$env:A3VR_SMOOTH_TURN_COUNTS_PER_SECOND = "1100"
$env:A3VR_VEHICLE_PITCH_COUNTS_PER_SECOND = "950"

# Start-Process resolves -WorkingDirectory as a wildcard path in Windows
# PowerShell 5.1. Steam Workshop titles commonly contain square brackets (for
# example "[Public Alpha]"), so use ProcessStartInfo's literal string paths.
$RuntimeStartInfo = New-Object System.Diagnostics.ProcessStartInfo
$RuntimeStartInfo.FileName = [System.IO.Path]::GetFullPath($Runtime)
$RuntimeStartInfo.WorkingDirectory = [System.IO.Path]::GetFullPath($ModDirectory)
$RuntimeStartInfo.UseShellExecute = $false
$RuntimeStartInfo.CreateNoWindow = $true
$RuntimeStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
$RuntimeProcess = New-Object System.Diagnostics.Process
$RuntimeProcess.StartInfo = $RuntimeStartInfo
if (-not $RuntimeProcess.Start()) {
    throw "A3VRRuntime_v31 could not be started."
}
try {
    Start-Sleep -Milliseconds 1200
    if ($RuntimeProcess.HasExited) {
        throw "A3VRRuntime_v31 exited before Arma started."
    }
    if ($UseArmaLauncher) {
        # The Launcher owns the enabled local-mod list and preset. Do not force
        # -mod on its command line: the user selects A3VR in the Mods tab and
        # explicitly clicks Play when ready.
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
        $ModList = @([System.IO.Path]::GetFullPath($ModDirectory))
        $ModArgument = "-mod=`"$($ModList -join ';')`""
        $GameArguments = @($ModArgument)
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
