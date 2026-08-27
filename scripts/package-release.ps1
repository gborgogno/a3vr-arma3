param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [string]$BuildDirectory = "",
    [Parameter(Mandatory = $true)]
    [string]$A3LibScript,
    [string]$OutputDirectory = "",
    [string]$PrereleaseLabel = "",
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

function Resolve-ProjectPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $Path))
}

if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path $ProjectRoot "build-current"
} else {
    $BuildDirectory = Resolve-ProjectPath $BuildDirectory
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $ProjectRoot "release"
} else {
    $OutputDirectory = Resolve-ProjectPath $OutputDirectory
}
$A3LibScript = Resolve-ProjectPath $A3LibScript

$CMake = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot "CMakeLists.txt")
if ($CMake -notmatch 'project\(A3VR VERSION ([0-9]+\.[0-9]+\.[0-9]+)') {
    throw "Could not read A3VR version from CMakeLists.txt."
}
$Version = $Matches[1]
if ($PrereleaseLabel -and $PrereleaseLabel -notmatch '^[0-9A-Za-z.-]+$') {
    throw "Invalid prerelease label: $PrereleaseLabel"
}
$PackageVersion = if ($PrereleaseLabel) { "$Version-$PrereleaseLabel" } else { $Version }
$PackageBaseName = "A3VR-Hybrid-v$PackageVersion"
$StagingRoot = Join-Path $OutputDirectory "$PackageBaseName-staging"
$ModDirectory = Join-Path $StagingRoot "@A3VR_Hybrid"
$AddonDestination = Join-Path $ModDirectory "addons"
$ZipPath = Join-Path $OutputDirectory "$PackageBaseName.zip"
$HashPath = "$ZipPath.sha256"

$NativeDll = Join-Path $BuildDirectory "$Configuration\A3VRHybridCore_x64.dll"
$RuntimeExe = Join-Path $BuildDirectory "$Configuration\A3VRRuntime_v31.exe"
foreach ($RequiredFile in @($NativeDll, $RuntimeExe, $A3LibScript)) {
    if (-not (Test-Path -LiteralPath $RequiredFile -PathType Leaf)) {
        throw "Required release input not found: $RequiredFile"
    }
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputRoot = [System.IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\') + '\'
$StagingFullPath = [System.IO.Path]::GetFullPath($StagingRoot)
if (-not $StagingFullPath.StartsWith($OutputRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean staging path outside output directory: $StagingFullPath"
}
if (Test-Path -LiteralPath $StagingRoot) {
    Remove-Item -LiteralPath $StagingRoot -Recurse -Force
}
foreach ($GeneratedFile in @($ZipPath, $HashPath)) {
    if (Test-Path -LiteralPath $GeneratedFile) {
        Remove-Item -LiteralPath $GeneratedFile -Force
    }
}

New-Item -ItemType Directory -Force -Path $AddonDestination | Out-Null
Copy-Item -Force -LiteralPath $NativeDll -Destination $ModDirectory
Copy-Item -Force -LiteralPath $RuntimeExe -Destination $ModDirectory
foreach ($ProjectFile in @(
    "a3vr-motion.ini",
    "mod.cpp",
    "README.md",
    "ROADMAP.md",
    "RELEASE_NOTES.md",
    "SECURITY.md",
    "LICENSE",
    "NOTICE",
    "THIRD_PARTY_LICENSES.md",
    "START_A3VR.cmd",
    "START_A3VR_LAUNCHER.cmd"
)) {
    Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot $ProjectFile) -Destination $ModDirectory
}
$PackagedScripts = Join-Path $ModDirectory "scripts"
New-Item -ItemType Directory -Force -Path $PackagedScripts | Out-Null
foreach ($ScriptFile in @("launch-a3vr.ps1", "set-a3vr-profile.ps1")) {
    Copy-Item -Force -LiteralPath (Join-Path $PSScriptRoot $ScriptFile) -Destination $PackagedScripts
}

$PboPath = Join-Path $AddonDestination "a3vr_hybrid.pbo"
$AddonSource = Join-Path $ProjectRoot "addons\a3vr"
Push-Location $AddonSource
try {
    & $Python $A3LibScript pbo -c -f $PboPath -e prefix a3vr_hybrid config.cpp functions
    if ($LASTEXITCODE -ne 0) {
        throw "PBO packer failed with exit code $LASTEXITCODE."
    }
    $PboEntries = & $Python $A3LibScript pbo -l -f $PboPath
    if ($LASTEXITCODE -ne 0) {
        throw "PBO validation failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$RequiredPboEntries = @(
    "config.cpp",
    "functions\fn_preStart.sqf",
    "functions\fn_postInit.sqf",
    "functions\fn_trackingLoop.sqf",
    "functions\fn_gameContextLoop.sqf"
)
foreach ($Entry in $RequiredPboEntries) {
    if ($PboEntries -notcontains $Entry) {
        throw "Packaged PBO is missing required entry: $Entry"
    }
}

Compress-Archive -LiteralPath $ModDirectory -DestinationPath $ZipPath -CompressionLevel Optimal
$Hash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $HashPath -Value "$Hash  $([System.IO.Path]::GetFileName($ZipPath))" -Encoding ascii

if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    throw "Release ZIP was not created: $ZipPath"
}

Write-Host "Packaged release: $ZipPath"
Write-Host "SHA-256: $Hash"
