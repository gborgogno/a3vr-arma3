@echo off
title A3VR - Arma 3 Hybrid VR
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launch-a3vr.ps1"
if errorlevel 1 pause
