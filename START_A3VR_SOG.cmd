@echo off
title A3VR - Arma 3 S.O.G. Prairie Fire
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launch-a3vr.ps1" -AdditionalMods "vn"
if errorlevel 1 pause
