@echo off
title A3VR - Smooth VR preset
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launch-a3vr.ps1" -UseArmaLauncher -GraphicsPreset StereoPerformance
if errorlevel 1 pause
