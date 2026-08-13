param(
    [double]$FovTop = 1.2,
    [double]$FovLeft = 2.1333333,
    [ValidateSet("Quality", "Balanced")]
    [string]$GraphicsPreset = "Quality"
)

$ErrorActionPreference = "Stop"
$ExpectedAspect = 16.0 / 9.0
if ([Math]::Abs(($FovLeft / $FovTop) - $ExpectedAspect) -gt 0.001) {
    throw "A3VR FOV values must preserve the 16:9 capture aspect ratio."
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
    Quality = @{
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
foreach ($Entry in $ProfileValues.GetEnumerator()) {
    $Text = Set-ArmaAssignment -Text $Text -Name $Entry.Key -Value $Entry.Value
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
        renderWidth = [string]$Selected.RenderWidth
        renderHeight = [string]$Selected.RenderHeight
        multiSampleCount = [string]$Selected.MultiSampleCount
        multiSampleQuality = "0"
        particlesQuality = [string]$Selected.ParticlesQuality
        cloudsQuality = [string]$Selected.CloudsQuality
        dynamicLightsQuality = "4"
        pipQuality = "6"
        HDRPrecision = "16"
        PPAA = "9"
        ppSSAO = "9"
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
Write-Host "Render target: $($Selected.RenderWidth)x$($Selected.RenderHeight); shadows: quality $($Selected.ShadowQuality), $($Selected.ShadowDistance)m."
Write-Host "Backups: $ProfileBackup and $ConfigBackup"
