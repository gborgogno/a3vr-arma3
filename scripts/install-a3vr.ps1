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
Copy-Item -Path (Join-Path $Package "*") -Destination $Target -Recurse -Force
Write-Host "Installed A3VR Hybrid at $Target"
Write-Host "Use INICIAR_A3VR_LAUNCHER.cmd to select A3VR Hybrid with other mods."
