param(
    [switch]$Windowed,
    [string]$GameDirectory = "",
    [switch]$UseArmaLauncher,
    [switch]$FastStart,
    [ValidateSet("Auto", "SteamVR", "Active")]
    [string]$OpenXrRuntime = "Auto",
    [ValidateSet("Stereo", "StereoPerformance")]
    [string]$GraphicsPreset = "Stereo"
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
$RuntimeConfig = Join-Path $ModDirectory "a3vr-runtime.ini"
$ConfiguredRuntime = ""
if (Test-Path -LiteralPath $RuntimeConfig -PathType Leaf) {
    $ConfiguredRuntime = [string](Get-Content -LiteralPath $RuntimeConfig |
        Where-Object { $_ -match '^\s*runtime\s*=' } |
        Select-Object -First 1)
    if ($ConfiguredRuntime) {
        $ConfiguredRuntime = ($ConfiguredRuntime -replace '^\s*runtime\s*=\s*', '').Trim()
    }
    if ($ConfiguredRuntime -and -not (Test-Path -LiteralPath $ConfiguredRuntime -PathType Leaf)) {
        throw "The configured OpenXR runtime manifest was not found: $ConfiguredRuntime"
    }
}
$SteamVrManifestCandidates = @(
    "C:\Program Files (x86)\Steam\steamapps\common\SteamVR\steamxr_win64.json",
    "C:\Program Files\Steam\steamapps\common\SteamVR\steamxr_win64.json"
)
$SteamVrManifest = $SteamVrManifestCandidates | Where-Object {
    Test-Path -LiteralPath $_ -PathType Leaf
} | Select-Object -First 1
$SteamVrRunning = $null -ne (Get-Process vrserver,vrmonitor -ErrorAction SilentlyContinue |
    Select-Object -First 1)
$UseSteamVr = $OpenXrRuntime -eq "SteamVR" -or
    ($OpenXrRuntime -eq "Auto" -and $SteamVrRunning)
if ($OpenXrRuntime -eq "SteamVR" -and -not $SteamVrManifest) {
    throw "SteamVR OpenXR was requested, but steamxr_win64.json was not found."
}
$RuntimeOverride = if ($ConfiguredRuntime) {
    $ConfiguredRuntime
} elseif ($UseSteamVr) {
    $SteamVrManifest
} else {
    ""
}
$EffectiveRuntimeManifest = $RuntimeOverride
if (-not $EffectiveRuntimeManifest) {
    $OpenXrRegistry = "HKLM:\SOFTWARE\Khronos\OpenXR\1"
    try {
        $EffectiveRuntimeManifest = [string](Get-ItemPropertyValue `
            -LiteralPath $OpenXrRegistry -Name ActiveRuntime -ErrorAction Stop)
    } catch {
        Write-Warning "A3VR could not read the active Windows OpenXR runtime; audio routing was left unchanged."
    }
}
$AudioRoute = if ($EffectiveRuntimeManifest -match '(?i)steamxr.*\.json$') {
    "SteamVR"
} else {
    "Keep"
}

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

if ($UseSteamVr -and -not $SteamVrRunning) {
    $SteamVrMonitor = Join-Path (Split-Path -Parent $SteamVrManifest) `
        "bin\win64\vrmonitor.exe"
    if (-not (Test-Path -LiteralPath $SteamVrMonitor -PathType Leaf)) {
        throw "SteamVR monitor was not found at $SteamVrMonitor"
    }
    Write-Host "Starting SteamVR before A3VR..."
    Start-Process -FilePath $SteamVrMonitor | Out-Null
    $SteamVrDeadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 250
        $SteamVrRunning = $null -ne (Get-Process vrserver -ErrorAction SilentlyContinue)
    } until ($SteamVrRunning -or [DateTime]::UtcNow -ge $SteamVrDeadline)
    if (-not $SteamVrRunning) {
        throw "SteamVR did not become ready within 30 seconds."
    }
}
Write-Host "A3VR OpenXR runtime: $EffectiveRuntimeManifest"

$ProfileTuner = Join-Path $PSScriptRoot "set-a3vr-profile.ps1"
if (Test-Path -LiteralPath $ProfileTuner) {
    & $ProfileTuner -GraphicsPreset $GraphicsPreset -AudioRoute $AudioRoute `
        -SteamVrManifest $EffectiveRuntimeManifest
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
if ($RuntimeOverride) {
    # Scope the override to the A3VR child process. Do not change the global
    # Windows OpenXR runtime or leak the choice into unrelated applications.
    $RuntimeStartInfo.EnvironmentVariables["XR_RUNTIME_JSON"] = $RuntimeOverride
}
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
