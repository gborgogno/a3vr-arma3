param(
    [double]$FovTop = 1.03,
    [double]$FovLeft = 2.06,
    [ValidateSet("Stereo", "StereoPerformance", "Ultra", "Quality", "Balanced")]
    [string]$GraphicsPreset = "Stereo",
    [ValidateSet("Keep", "SteamVR")]
    [string]$AudioRoute = "Keep",
    [string]$SteamVrManifest = ""
)

$ErrorActionPreference = "Stop"
$ExpectedAspect = if ($GraphicsPreset -like "Stereo*") { 2.0 } else { 16.0 / 9.0 }
if ([Math]::Abs(($FovLeft / $FovTop) - $ExpectedAspect) -gt 0.001) {
    throw "A3VR FOV values must preserve the selected capture aspect ratio ($ExpectedAspect)."
}

$Documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
$ProfileDirectory = Join-Path $Documents "Arma 3"
$ArmaConfig = Join-Path $ProfileDirectory "Arma3.cfg"
$Profile = Get-ChildItem -LiteralPath $ProfileDirectory -Filter "*.Arma3Profile" -File `
    -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch "\.(3den|vars)\.Arma3Profile$"
    } | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($null -eq $Profile) {
    Write-Warning "A3VR did not find an Arma 3 player profile; graphics were not changed."
    return
}

$Presets = @{
    Stereo = @{
        OutputWidth = 2560
        OutputHeight = 1280
        DisplayMode = 2
        RenderWidth = 2560
        RenderHeight = 1280
        MultiSampleCount = 2
        SceneComplexity = 750000
        ShadowDistance = 60
        ViewDistance = 2600
        ObjectViewDistance = 1500
        PipViewDistance = 850
        TerrainGrid = 6.25
        ShadowQuality = 3
        ParticlesQuality = 2
        CloudsQuality = 1
        Sharpen = 0.8
    }
    StereoPerformance = @{
        OutputWidth = 1920
        OutputHeight = 960
        DisplayMode = 2
        RenderWidth = 1920
        RenderHeight = 960
        MultiSampleCount = 1
        SceneComplexity = 750000
        ShadowDistance = 60
        ViewDistance = 2600
        ObjectViewDistance = 1500
        PipViewDistance = 850
        TerrainGrid = 6.25
        ShadowQuality = 3
        ParticlesQuality = 2
        CloudsQuality = 1
        Sharpen = 1.1
    }
    Ultra = @{
        OutputWidth = 1920
        OutputHeight = 1080
        DisplayMode = 2
        RenderWidth = 3840
        RenderHeight = 2160
        MultiSampleCount = 2
        SceneComplexity = 1200000
        ShadowDistance = 80
        ViewDistance = 3000
        ObjectViewDistance = 1800
        PipViewDistance = 1200
        TerrainGrid = 3.125
        ShadowQuality = 4
        ParticlesQuality = 2
        CloudsQuality = 3
        Sharpen = 0.9
    }
    Quality = @{
        OutputWidth = 1920
        OutputHeight = 1080
        DisplayMode = 2
        RenderWidth = 2560
        RenderHeight = 1440
        MultiSampleCount = 2
        SceneComplexity = 1000000
        ShadowDistance = 120
        ViewDistance = 3500
        ObjectViewDistance = 2200
        PipViewDistance = 1000
        TerrainGrid = 3.125
        ShadowQuality = 4
        ParticlesQuality = 2
        CloudsQuality = 3
        Sharpen = 1.25
    }
    Balanced = @{
        OutputWidth = 1920
        OutputHeight = 1080
        DisplayMode = 2
        RenderWidth = 2304
        RenderHeight = 1296
        MultiSampleCount = 1
        SceneComplexity = 850000
        ShadowDistance = 100
        ViewDistance = 3000
        ObjectViewDistance = 1800
        PipViewDistance = 750
        TerrainGrid = 6.25
        ShadowQuality = 3
        ParticlesQuality = 1
        CloudsQuality = 2
        Sharpen = 1.35
    }
}
$Selected = $Presets[$GraphicsPreset]

function Set-ArmaAssignment {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Value
    )
    $Pattern = "(?m)^$([Text.RegularExpressions.Regex]::Escape($Name))\s*=\s*[^;]+;"
    $Replacement = "$Name=$Value;"
    if ([Text.RegularExpressions.Regex]::IsMatch($Text, $Pattern)) {
        return [Text.RegularExpressions.Regex]::Replace($Text, $Pattern, $Replacement)
    }
    return $Text.TrimEnd() + [Environment]::NewLine + $Replacement + [Environment]::NewLine
}

function Find-SteamVrAudioEndpoint {
    param(
        [Parameter(Mandatory)] [string]$DeviceName,
        [Parameter(Mandatory)] [ValidateSet("Render", "Capture")] [string]$Flow
    )
    $SteamRoots = @()
    if ($SteamVrManifest -and (Test-Path -LiteralPath $SteamVrManifest -PathType Leaf)) {
        $SteamVrDirectory = Split-Path -Parent ([IO.Path]::GetFullPath($SteamVrManifest))
        $SteamRoots += [IO.Path]::GetFullPath((Join-Path $SteamVrDirectory "..\..\.."))
    }
    foreach ($ProgramRoot in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if ($ProgramRoot) { $SteamRoots += Join-Path $ProgramRoot "Steam" }
    }
    $SteamRoots = $SteamRoots | Select-Object -Unique | Where-Object {
        $_ -and (Test-Path -LiteralPath $_ -PathType Container)
    }
    foreach ($SteamRoot in $SteamRoots) {
        $Log = Join-Path $SteamRoot "logs\vrmonitor.txt"
        if (-not (Test-Path -LiteralPath $Log -PathType Leaf)) { continue }
        $Pattern = [regex]::Escape($DeviceName) +
            '.*?(\{0\.0\.' + $(if ($Flow -eq "Render") { '0' } else { '1' }) +
            '\.00000000\}\.\{[0-9a-fA-F-]+\})'
        $Match = Select-String -LiteralPath $Log -Pattern $Pattern -AllMatches |
            ForEach-Object { $_.Matches } | Select-Object -Last 1
        if ($null -ne $Match) { return $Match.Groups[1].Value }
    }
    throw "SteamVR audio endpoint '$DeviceName' was not found. Start SteamVR once and retry."
}

$Text = [IO.File]::ReadAllText($Profile.FullName)
$TopText = $FovTop.ToString("0.#######", [Globalization.CultureInfo]::InvariantCulture)
$LeftText = $FovLeft.ToString("0.#######", [Globalization.CultureInfo]::InvariantCulture)
$ProfileValues = [ordered]@{
    fovTop = $TopText
    fovLeft = $LeftText
    anisoFilter = "16"
    textureQuality = "3"
    shadowQuality = [string]$Selected.ShadowQuality
    sceneComplexity = [string]$Selected.SceneComplexity
    shadowZDistance = [string]$Selected.ShadowDistance
    viewDistance = [string]$Selected.ViewDistance
    preferredObjectViewDistance = [string]$Selected.ObjectViewDistance
    pipViewDistance = [string]$Selected.PipViewDistance
    terrainGrid = $Selected.TerrainGrid.ToString(
        "0.###", [Globalization.CultureInfo]::InvariantCulture)
}
if ($AudioRoute -eq "SteamVR") {
    $SteamOutput = Find-SteamVrAudioEndpoint `
        -DeviceName "Steam Streaming Speakers" -Flow Render
    $SteamInput = Find-SteamVrAudioEndpoint `
        -DeviceName "Steam Streaming Microphone" -Flow Capture
    $ProfileValues.preferredOutputDevice = '"' + $SteamOutput + '"'
    $ProfileValues.preferredInputDevice = '"' + $SteamInput + '"'
}
foreach ($Entry in $ProfileValues.GetEnumerator()) {
    $Text = Set-ArmaAssignment -Text $Text -Name $Entry.Key -Value $Entry.Value
}

$AudioBackup = "not created"
if ($AudioRoute -ne "Keep") {
    $AudioBackup = "$($Profile.FullName).a3vr-pre-steamvr-audio"
    if (-not (Test-Path -LiteralPath $AudioBackup)) {
        Copy-Item -LiteralPath $Profile.FullName -Destination $AudioBackup
    }
}
$ProfileBackup = "$($Profile.FullName).a3vr-pre-vr-quality"
if (-not (Test-Path -LiteralPath $ProfileBackup)) {
    Copy-Item -LiteralPath $Profile.FullName -Destination $ProfileBackup
}
[IO.File]::WriteAllText(
    $Profile.FullName, $Text, [Text.UTF8Encoding]::new($false))

$ConfigBackup = "not created"
if (Test-Path -LiteralPath $ArmaConfig -PathType Leaf) {
    $ConfigText = [IO.File]::ReadAllText($ArmaConfig)
    $ConfigValues = [ordered]@{
        displayMode = [string]$Selected.DisplayMode
        winX = "0"
        winY = "0"
        winWidth = [string]$Selected.OutputWidth
        winHeight = [string]$Selected.OutputHeight
        winDefWidth = [string]$Selected.OutputWidth
        winDefHeight = [string]$Selected.OutputHeight
        fullScreenWidth = [string]$Selected.OutputWidth
        fullScreenHeight = [string]$Selected.OutputHeight
        renderWidth = [string]$Selected.RenderWidth
        renderHeight = [string]$Selected.RenderHeight
        multiSampleCount = [string]$Selected.MultiSampleCount
        multiSampleQuality = "0"
        particlesQuality = [string]$Selected.ParticlesQuality
        cloudsQuality = [string]$Selected.CloudsQuality
        dynamicLightsQuality = "4"
        pipQuality = "6"
        HDRPrecision = "16"
        PPAA = if ($GraphicsPreset -like "Stereo*") { "8" } else { "9" }
        ppSSAO = if ($GraphicsPreset -like "Stereo*") { "3" } else { "9" }
        ppBloom = "0"
        ppRotBlur = "0"
        ppRadialBlur = "0"
        ppDOF = "0"
        ppSharpen = $Selected.Sharpen.ToString(
            "0.##", [Globalization.CultureInfo]::InvariantCulture)
    }
    foreach ($Entry in $ConfigValues.GetEnumerator()) {
        $ConfigText = Set-ArmaAssignment -Text $ConfigText -Name $Entry.Key -Value $Entry.Value
    }
    $ConfigBackup = "$ArmaConfig.a3vr-pre-vr-quality"
    if (-not (Test-Path -LiteralPath $ConfigBackup)) {
        Copy-Item -LiteralPath $ArmaConfig -Destination $ConfigBackup
    }
    [IO.File]::WriteAllText(
        $ArmaConfig, $ConfigText, [Text.UTF8Encoding]::new($false))
} else {
    Write-Warning "A3VR did not find Arma3.cfg; render resolution was not changed."
}

Write-Host "A3VR applied the $GraphicsPreset VR graphics preset to $($Profile.Name)."
Write-Host "VR capture: $($Selected.OutputWidth)x$($Selected.OutputHeight); render target: $($Selected.RenderWidth)x$($Selected.RenderHeight)."
Write-Host "Shadows: quality $($Selected.ShadowQuality), $($Selected.ShadowDistance)m."
if ($AudioRoute -eq "SteamVR") {
    Write-Host "SteamVR audio: $SteamOutput; microphone: $SteamInput."
    Write-Host "Audio backup: $AudioBackup"
}
Write-Host "Backups: $ProfileBackup and $ConfigBackup"
