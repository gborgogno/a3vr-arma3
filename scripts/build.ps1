param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildDirectory = Join-Path $ProjectRoot "build-current"

cmake -S $ProjectRoot -B $BuildDirectory -G "Visual Studio 17 2022" -A x64
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed with exit code $LASTEXITCODE" }
cmake --build $BuildDirectory --config $Configuration
if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
ctest --test-dir $BuildDirectory -C $Configuration --output-on-failure
if ($LASTEXITCODE -ne 0) { throw "Tests failed with exit code $LASTEXITCODE" }

Write-Host "DLL: $BuildDirectory\$Configuration\A3VRCore_x64.dll"
Write-Host "Server: $BuildDirectory\$Configuration\A3VRRuntime_v24.exe"
