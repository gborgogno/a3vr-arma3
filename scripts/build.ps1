param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [string]$BuildDirectory = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path $ProjectRoot "build-current"
} elseif (-not [System.IO.Path]::IsPathRooted($BuildDirectory)) {
    $BuildDirectory = Join-Path $ProjectRoot $BuildDirectory
}
$BuildDirectory = [System.IO.Path]::GetFullPath($BuildDirectory)

# Codex/desktop can inherit both `Path` and `PATH`. MSBuild treats environment
# names case-insensitively and CL.exe then fails with MSB6001 before compiling.
# Launch build tools with one explicitly normalized environment block.
$CleanEnvironment = [ordered]@{}
$PathValue = $null
foreach ($Entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
    if ([string]$Entry.Key -ieq "Path") {
        if ($null -eq $PathValue -or [string]$Entry.Key -ceq "Path") {
            $PathValue = [string]$Entry.Value
        }
    } else {
        $CleanEnvironment[[string]$Entry.Key] = [string]$Entry.Value
    }
}
$CleanEnvironment["Path"] = $PathValue

function Invoke-A3VRBuildTool {
    param(
        [Parameter(Mandatory)] [string]$Executable,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [Parameter(Mandatory)] [string]$FailureLabel
    )
    $StartInfo = [Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $Executable
    $StartInfo.WorkingDirectory = $ProjectRoot
    $StartInfo.UseShellExecute = $false
    $StartInfo.Environment.Clear()
    foreach ($Entry in $CleanEnvironment.GetEnumerator()) {
        $StartInfo.Environment[[string]$Entry.Key] = [string]$Entry.Value
    }
    if ($null -ne $StartInfo.ArgumentList) {
        foreach ($Argument in $Arguments) {
            $StartInfo.ArgumentList.Add($Argument)
        }
    } else {
        # Windows PowerShell 5.1 exposes only the legacy Arguments string.
        # Quote with the CommandLineToArgvW rules so paths containing spaces and
        # trailing backslashes reach CMake/CTest unchanged.
        $QuotedArguments = foreach ($Argument in $Arguments) {
            if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') {
                $Argument
                continue
            }
            $Escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
            $Escaped = [regex]::Replace($Escaped, '(\\+)$', '$1$1')
            '"' + $Escaped + '"'
        }
        $StartInfo.Arguments = $QuotedArguments -join ' '
    }
    $Process = [Diagnostics.Process]::Start($StartInfo)
    $Process.WaitForExit()
    if ($Process.ExitCode -ne 0) {
        throw "$FailureLabel failed with exit code $($Process.ExitCode)"
    }
}

$CMake = (Get-Command cmake -ErrorAction Stop).Source
$CTest = (Get-Command ctest -ErrorAction Stop).Source
Invoke-A3VRBuildTool -Executable $CMake -FailureLabel "CMake configure" `
    -Arguments @("-S", $ProjectRoot, "-B", $BuildDirectory,
        "-G", "Visual Studio 17 2022", "-A", "x64")
Invoke-A3VRBuildTool -Executable $CMake -FailureLabel "Build" `
    -Arguments @("--build", $BuildDirectory, "--config", $Configuration)
Invoke-A3VRBuildTool -Executable $CTest -FailureLabel "Tests" `
    -Arguments @("--test-dir", $BuildDirectory, "-C", $Configuration,
        "--output-on-failure")

Write-Host "DLL: $BuildDirectory\$Configuration\A3VRHybridCore_x64.dll"
Write-Host "Server: $BuildDirectory\$Configuration\A3VRRuntime_v31.exe"
