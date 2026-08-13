param(
    [double]$FovTop = 1.2,
    [double]$FovLeft = 2.1333333
)

$ErrorActionPreference = "Stop"
$ExpectedAspect = 16.0 / 9.0
if ([Math]::Abs(($FovLeft / $FovTop) - $ExpectedAspect) -gt 0.001) {
    throw "A3VR FOV values must preserve the 16:9 capture aspect ratio."
}

$Documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
$ProfileDirectory = Join-Path $Documents "Arma 3"
$Profile = Get-ChildItem -LiteralPath $ProfileDirectory -Filter "*.Arma3Profile" -File `
    -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch "\.(3den|vars)\.Arma3Profile$"
    } | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($null -eq $Profile) {
    Write-Warning "A3VR did not find an Arma 3 player profile; FOV was not changed."
    return
}

$Text = [IO.File]::ReadAllText($Profile.FullName)
$TopText = $FovTop.ToString("0.#######", [Globalization.CultureInfo]::InvariantCulture)
$LeftText = $FovLeft.ToString("0.#######", [Globalization.CultureInfo]::InvariantCulture)
$TopPattern = '(?m)^fovTop\s*=\s*[^;]+;'
$LeftPattern = '(?m)^fovLeft\s*=\s*[^;]+;'
if (-not [Text.RegularExpressions.Regex]::IsMatch($Text, $TopPattern) -or
    -not [Text.RegularExpressions.Regex]::IsMatch($Text, $LeftPattern)) {
    throw "A3VR found $($Profile.Name), but it has no editable fovTop/fovLeft entries."
}

$Updated = [Text.RegularExpressions.Regex]::Replace($Text, $TopPattern, "fovTop=$TopText;")
$Updated = [Text.RegularExpressions.Regex]::Replace($Updated, $LeftPattern, "fovLeft=$LeftText;")
if ($Updated -eq $Text) {
    return
}

$Backup = "$($Profile.FullName).a3vr-pre-fov"
if (-not (Test-Path -LiteralPath $Backup)) {
    Copy-Item -LiteralPath $Profile.FullName -Destination $Backup
}
[IO.File]::WriteAllText(
    $Profile.FullName, $Updated, [Text.UTF8Encoding]::new($false))
Write-Host "A3VR calibrated 16:9 FOV in $($Profile.Name) (backup: $Backup)"
