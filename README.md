# A3VR

Experimental hybrid VR bridge for 64-bit Arma 3. A3VR presents the game's
D3D11 output through OpenXR, publishes headset movement through FreeTrack for
6DoF head tracking, and maps OpenXR controllers to Arma's native input.

This is a community experiment, not an official Bohemia Interactive product.
It currently prioritizes comfort, compatibility and native Arma weapon
behavior over full room-scale VR interaction.

## Current features

- OpenXR headset presentation.
- 6DoF headset tracking through Arma's FreeTrack input path.
- Native Arma weapon, muzzle, projectiles, effects and optics.
- Right-controller motion aiming without replacing the weapon model.
- Controller movement, firing, aiming, sprint, reload, interaction, fire mode
  and weapon switching.
- Automatic runtime cleanup when Arma exits.
- Recenter and motion-aim toggles.

## Controls

The default bindings target Oculus Touch, Valve Index and Microsoft motion
controllers where matching OpenXR paths are available.

| Input | Action |
| --- | --- |
| Headset | Arma head tracking |
| Right controller movement | Move the native Arma aim |
| Right trigger | Fire |
| Right grip | Aim down sights |
| Right A | Reload |
| Right thumbstick click | Fire mode |
| Right B | Toggle motion aiming |
| Left thumbstick | Move |
| Left thumbstick click | Sprint |
| Left X / A | Interact |
| Left Y / B | Switch primary/sidearm |
| F8 | Recenter head tracking |
| F9 | Toggle motion aiming |

Turn motion aiming off with right B or F9 before using vehicle controls when
the controller-driven mouse movement is inconvenient.

## Architecture

- `A3VRRuntime_v23.exe` owns the OpenXR session, tracks the headset and
  controllers, submits frames and publishes FreeTrack data.
- `A3VRCore_x64.dll` is loaded by Arma, captures the D3D11 backbuffer and
  exchanges tracking/render data with the runtime through shared memory.
- The small SQF addon starts the bridge and exposes the current OpenXR sample
  as `missionNamespace getVariable "A3VR_tracking"`.

OpenXR and MinHook are fetched from pinned upstream commits during the CMake
configure step; generated build trees and third-party installers are not
committed.

## Requirements

- Windows 10/11 x64.
- 64-bit Arma 3.
- An active OpenXR runtime and connected headset.
- Visual Studio 2022 C++ Build Tools and CMake 3.24+ to build.
- Arma 3 Tools/Addon Builder to package the PBO.

## Build and test

```powershell
.\scripts\build.ps1 -Configuration Release
```

The script configures CMake, builds `A3VRCore_x64.dll` and
`A3VRRuntime_v23.exe`, then runs the automated math and extension smoke tests.

## Package and install

```powershell
.\scripts\package.ps1 -Configuration Release
Copy-Item -Recurse -Force .\dist\@A3VR "D:\SteamLibrary\steamapps\common\Arma 3\"
```

Change the destination to your Arma 3 directory. The package script accepts a
custom Addon Builder path through `-AddonBuilder`.

Start the installed package with `INICIAR_A3VR.cmd`. The launcher searches
common Steam locations. For a custom library, either pass `-GameDirectory` to
`scripts\launch-a3vr.ps1` or set `ARMA3_DIR`.

## Extension commands

```sqf
"A3VRCore" callExtension "version";
"A3VRCore" callExtension "start";
"A3VRCore" callExtension "status";
"A3VRCore" callExtension "capture";
private _sample = parseSimpleArray ("A3VRCore" callExtension "pose");
"A3VRCore" callExtension "probe";
```

## Limitations and safety

- This remains experimental and is not a native Arma 3 VR renderer.
- Stereo/depth behavior depends on the selected presentation mode and game
  output; comfort-mono remains the compatibility default.
- Motion aiming drives Arma's native mouse-look rather than independent
  weapon bones.
- Use without BattlEye. Test locally or only on servers that explicitly permit
  client-side native modifications.
- Stop immediately if the image causes eye strain, nausea or headache.

The project does not modify Arma network traffic or overwrite base-game files.
All installed files live inside the A3VR mod directory.
