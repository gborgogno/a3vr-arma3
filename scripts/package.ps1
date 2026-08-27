param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [string]$BuildDirectory = "",
    [string]$AddonBuilder = "C:\Program Files (x86)\Steam\steamapps\common\Arma 3 Tools\AddonBuilder\AddonBuilder.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path $ProjectRoot "build-current"
} elseif (-not [System.IO.Path]::IsPathRooted($BuildDirectory)) {
    $BuildDirectory = Join-Path $ProjectRoot $BuildDirectory
}
$ModDirectory = Join-Path $ProjectRoot "dist\@A3VR_Hybrid"
$AddonDestination = Join-Path $ModDirectory "addons"
$NativeDll = Join-Path $BuildDirectory "$Configuration\A3VRHybridCore_x64.dll"
$ServerExe = Join-Path $BuildDirectory "$Configuration\A3VRRuntime_v31.exe"

if (-not (Test-Path -LiteralPath $NativeDll)) {
    throw "Build A3VR first: .\scripts\build.ps1 -Configuration $Configuration"
}
if (-not (Test-Path -LiteralPath $ServerExe)) {
    throw "Build A3VRRuntime first: .\scripts\build.ps1 -Configuration $Configuration"
}

# CMake/MSBuild owns source-to-target freshness. Comparing every source file to
# both outputs gives false failures when only one of the two targets changed.
if (-not (Test-Path -LiteralPath $AddonBuilder)) {
    throw "AddonBuilder.exe was not found. Pass its path with -AddonBuilder."
}

New-Item -ItemType Directory -Force -Path $AddonDestination | Out-Null
$ExpandedAddon = Join-Path $AddonDestination "a3vr_hybrid"
if (Test-Path -LiteralPath $ExpandedAddon -PathType Container) {
    # Old local packages sometimes left an unpacked source mirror beside the
    # PBO. It is not loaded by Arma and can silently retain retired scripts.
    Remove-Item -LiteralPath $ExpandedAddon -Recurse -Force
}
$ObsoleteArtifacts = @(
    "A3VR_x64.dll",
    "A3VRCore_x64.dll",
    "A3VRBridge_x64.dll",
    "A3VRClient_x64.dll",
    "A3VRServer.exe",
    "A3VRRuntime.exe",
    "A3VRRuntime_v5.exe",
    "A3VRRuntime_v6.exe",
    "A3VRRuntime_v7.exe",
    "A3VRRuntime_v8.exe",
    "A3VRRuntime_v9.exe",
    "A3VRRuntime_v10.exe",
    "A3VRRuntime_v11.exe",
    "A3VRRuntime_v12.exe",
    "A3VRRuntime_v13.exe",
    "A3VRRuntime_v14.exe",
    "A3VRRuntime_v15.exe",
    "A3VRRuntime_v16.exe",
    "A3VRRuntime_v17.exe",
    "A3VRRuntime_v18.exe",
    "A3VRRuntime_v19.exe",
    "A3VRRuntime_v20.exe",
    "A3VRRuntime_v21.exe",
    "A3VRRuntime_v22.exe",
    "A3VRRuntime_v23.exe",
    "A3VRRuntime_v24.exe",
    "A3VRRuntime_v25.exe",
    "A3VRRuntime_v26.exe",
    "A3VRRuntime_v27.exe",
    "A3VRRuntime_v28.exe",
    "A3VRRuntime_v29.exe",
    "A3VRRuntime_v30.exe",
    "A3VRIPC_x64.dll",
    "A3VRHost.exe",
    "INICIAR_A3VR.cmd",
    "INICIAR_A3VR_LAUNCHER.cmd",
    "INICIAR_A3VR_SOG.cmd"
)
foreach ($Artifact in $ObsoleteArtifacts) {
    $ObsoletePath = Join-Path $ModDirectory $Artifact
    if (Test-Path -LiteralPath $ObsoletePath) {
        Remove-Item -LiteralPath $ObsoletePath -Force
    }
}
$LegacyPbo = Join-Path $AddonDestination "a3vr.pbo"
if (Test-Path -LiteralPath $LegacyPbo -PathType Leaf) {
    Remove-Item -LiteralPath $LegacyPbo -Force
}
Copy-Item -Force -LiteralPath $NativeDll -Destination $ModDirectory
Copy-Item -Force -LiteralPath $ServerExe -Destination $ModDirectory
if (Test-Path -LiteralPath (Join-Path $ProjectRoot "a3vr-runtime.ini")) {
    Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot "a3vr-runtime.ini") `
        -Destination $ModDirectory
}
if (Test-Path -LiteralPath (Join-Path $ProjectRoot "a3vr-motion.ini")) {
    Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot "a3vr-motion.ini") `
        -Destination $ModDirectory
}
Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot "mod.cpp") -Destination $ModDirectory
Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot "README.md") -Destination $ModDirectory
Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot "ROADMAP.md") -Destination $ModDirectory
foreach ($DocumentationFile in @(
    "RELEASE_NOTES.md",
    "SECURITY.md",
    "LICENSE",
    "NOTICE",
    "THIRD_PARTY_LICENSES.md"
)) {
    Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot $DocumentationFile) `
        -Destination $ModDirectory
}
$PackagedScripts = Join-Path $ModDirectory "scripts"
New-Item -ItemType Directory -Force -Path $PackagedScripts | Out-Null
Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot "START_A3VR.cmd") -Destination $ModDirectory
Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot "START_A3VR_LAUNCHER.cmd") -Destination $ModDirectory
Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot "scripts\launch-a3vr.ps1") -Destination $PackagedScripts
Copy-Item -Force -LiteralPath (Join-Path $ProjectRoot "scripts\set-a3vr-profile.ps1") -Destination $PackagedScripts

$AddonSource = Join-Path $ProjectRoot "addons\a3vr"
$ToolsDirectory = Split-Path -Parent (Split-Path -Parent $AddonBuilder)
# Stage only the active addon sources. Retired arm/HUD/PiP experiments are
# intentionally excluded so local and CI packages contain the same core files.
$PackageWorkRoot = Join-Path $ProjectRoot ".tmp\package-a3vr"
$PackageSource = Join-Path $PackageWorkRoot "a3vr_hybrid"
if (Test-Path -LiteralPath $PackageWorkRoot) {
    Remove-Item -LiteralPath $PackageWorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $PackageSource | Out-Null
Copy-Item -Force -LiteralPath (Join-Path $AddonSource "config.cpp") `
    -Destination $PackageSource
Copy-Item -Recurse -Force -LiteralPath (Join-Path $AddonSource "functions") `
    -Destination $PackageSource

& $AddonBuilder $PackageSource $AddonDestination -packonly -clear `
    -prefix=a3vr_hybrid `
    "-toolsDirectory=$ToolsDirectory"
if ($LASTEXITCODE -ne 0) {
    throw "Addon Builder failed with exit code $LASTEXITCODE"
}

$Pbo = Join-Path $AddonDestination "a3vr_hybrid.pbo"
$AddonBuilderPbo = Join-Path $AddonDestination "a3vr.pbo"
if (Test-Path -LiteralPath $AddonBuilderPbo -PathType Leaf) {
    Move-Item -LiteralPath $AddonBuilderPbo -Destination $Pbo -Force
}
if (-not (Test-Path -LiteralPath $Pbo)) {
    throw "Addon Builder finished without producing $Pbo"
}

Write-Host "Packaged mod: $ModDirectory"
