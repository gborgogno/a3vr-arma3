@echo off
title A3VR - SteamVR
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launch-a3vr.ps1" -FastStart -OpenXrRuntime SteamVR
if errorlevel 1 pause
