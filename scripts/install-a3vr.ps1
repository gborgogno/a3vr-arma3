param(
    [string]$GameDirectory = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Package = Join-Path $ProjectRoot "dist\@A3VR_Hybrid"

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
if (-not (Test-Path -LiteralPath $Package)) {
    throw "Package not found at $Package. Run scripts\package.ps1 first."
}

$Target = Join-Path $GameDirectory "@A3VR_Hybrid"
if ((Split-Path -Leaf $Target) -ne "@A3VR_Hybrid") {
    throw "Unexpected install target: $Target"
}
New-Item -ItemType Directory -Force -Path $Target | Out-Null
$ResolvedTarget = [System.IO.Path]::GetFullPath($Target).TrimEnd('\')
Get-ChildItem -LiteralPath $Target -Filter "A3VRRuntime_v*.exe" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "A3VRRuntime_v30.exe" } | ForEach-Object {
        if ([System.IO.Path]::GetFullPath($_.DirectoryName).TrimEnd('\') -ne $ResolvedTarget) {
            throw "Refusing to remove runtime outside install target: $($_.FullName)"
        }
        Remove-Item -LiteralPath $_.FullName -Force
    }
$LegacyLaunchers = @(
    "INICIAR_A3VR.cmd",
    "INICIAR_A3VR_LAUNCHER.cmd",
    "INICIAR_A3VR_SOG.cmd"
)
foreach ($LegacyLauncher in $LegacyLaunchers) {
    $LegacyPath = Join-Path $Target $LegacyLauncher
    if (Test-Path -LiteralPath $LegacyPath -PathType Leaf) {
        if ([System.IO.Path]::GetFullPath((Split-Path -Parent $LegacyPath)).TrimEnd('\') -ne
            $ResolvedTarget) {
            throw "Refusing to remove legacy launcher outside install target: $LegacyPath"
        }
        Remove-Item -LiteralPath $LegacyPath -Force
    }
}
Copy-Item -Path (Join-Path $Package "*") -Destination $Target -Recurse -Force
Write-Host "Installed A3VR Hybrid at $Target"
Write-Host "Enable A3VR Hybrid in the official Arma 3 Launcher; the VR runtime starts automatically."
Write-Host "START_A3VR_LAUNCHER.cmd remains available as a diagnostic fallback."
