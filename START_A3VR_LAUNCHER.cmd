@echo off
title A3VR - Arma 3 Launcher with other mods
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launch-a3vr.ps1" -UseArmaLauncher
if errorlevel 1 pause
