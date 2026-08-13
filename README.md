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
- Native first-person weapon, hands, attachments, muzzle effects and
  projectiles; no detached or floating weapon copy is created.
- F8 recenters the VR spatial basis.
- Left-hand 6DoF pose and controller-derived finger-curl telemetry.
- Local left-hand calibration skeleton with articulated fingers (F7).
- Controller movement, firing, aiming, sprint, reload, interaction, fire mode
  and weapon switching.
- Automatic VR-controller cursor in Arma menus and smooth body turning.
- Automatic OpenXR runtime startup when the addon is enabled.
- Early logo/menu capture with stable swapchain handover.
- Automatic runtime cleanup when Arma exits.
- Recenter and motion-aim toggles.

## Controls

The default bindings target Oculus Touch, Valve Index and Microsoft motion
controllers where matching OpenXR paths are available.

| Input | Action |
| --- | --- |
| Headset | Arma head tracking |
| Right controller movement | Aim in game / point at the UI cursor in menus |
| Right trigger | Fire |
| Right grip | Aim down sights |
| Right A | Reload |
| Right thumbstick click | Fire mode |
| Right B | Vault / step over |
| Left thumbstick | Move and strafe |
| Right thumbstick horizontal | Smooth camera/body turn |
| Right thumbstick up/down | Stand / crouch |
| Left thumbstick click | Sprint |
| Left X / A | Interact |
| Left Y / B | Switch primary/sidearm |
| F8 | Recenter head tracking |
| F7 | Toggle the left-hand calibration skeleton |
| F9 | Toggle motion aiming |
| F10 | Force/release VR UI cursor mode |

F9 remains an emergency keyboard-only motion-aim toggle for vehicle testing.
Magnified and engine-driven PiP optics still use right grip because Arma only
activates those render paths through its native optics camera.

## Architecture

- `A3VRRuntime_v30.exe` owns the OpenXR session, tracks the headset and
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
`A3VRRuntime_v30.exe`, then runs the automated math and extension smoke tests.

## Package and install

```powershell
.\scripts\package.ps1 -Configuration Release
.\scripts\install-a3vr.ps1
```

The installer creates `@A3VR_Hybrid` beside the game without touching an
existing `@A3VR` installation. Pass `-GameDirectory` when Arma is outside the
common Steam locations. The package script accepts a custom Addon Builder path
through `-AddonBuilder`.

## Releases

Tags in the `vMAJOR.MINOR.PATCH` format trigger the release CI/CD. The pipeline
checks the version declared in `CMakeLists.txt`, builds and tests the runtime,
packages an installable `@A3VR_Hybrid` with `a3vr.pbo`, and publishes a ZIP plus
its SHA-256 file in the GitHub Release.

The CI PBO uses the pinned open-source `4d4a5852/a3lib.py` packer. Local
development packaging continues to use the official Addon Builder through
`scripts/package.ps1`.

For normal use, extract `@A3VR_Hybrid` into the Arma 3 directory, enable
`A3VR - Arma 3 Hybrid VR` in the official launcher, disable BattlEye, and press
Play. The addon's `preStart` function loads the native extension before the
title screen, and the extension starts one `A3VRRuntime_v30.exe` instance
automatically. No separate script is required.

`START_A3VR.cmd`, `START_A3VR_LAUNCHER.cmd`, and `START_A3VR_SOG.cmd` remain
available as diagnostic or direct-launch fallbacks. For a custom Steam library,
pass `-GameDirectory` to `scripts\launch-a3vr.ps1` or set `ARMA3_DIR`.

## Play with other mods

Enable `A3VR - Arma 3 Hybrid VR` together with CBA, ACE, RHS or any other
desired mods in the official Arma 3 Launcher. The runtime starts automatically
when Arma loads the A3VR addon. `START_A3VR_LAUNCHER.cmd` can still prestart the
runtime before opening the official launcher when diagnosing headset or
FreeTrack enumeration problems.

Do not enable two A3VR variants in the same preset. In particular, leave the
older `@A3VR` Stable build disabled when using `@A3VR_Hybrid`.

For a direct command-line launch, pass a semicolon-separated list:

```powershell
.\scripts\launch-a3vr.ps1 -AdditionalMods "@CBA_A3;@ace;@RHSUSAF"
```

Absolute Workshop mod paths are also accepted. A3VR is always placed first in
the resulting `-mod` list.

## Extension commands

```sqf
"A3VRCore" callExtension "version";
"A3VRCore" callExtension "start";
"A3VRCore" callExtension "status";
"A3VRCore" callExtension "capture";
private _sample = parseSimpleArray ("A3VRCore" callExtension "pose");
"A3VRCore" callExtension "probe";
```

The `pose` result keeps its existing fields and appends a five-value
left-finger curl array ordered thumb, index, middle, ring and pinky.
Controller-derived curls are an approximation; true independent joints
require optical hand tracking.

The F7 hand is deliberately a line-art calibration proxy. It verifies the
wrist position, axes, scale and finger inputs without replacing or moving
Arma's weapon. The small red, green and blue lines show hand right, forward
and up respectively. A skinned P3D glove replaces this proxy after calibration.

Head rotation defaults to a natural-but-damped `0.65` gain. Advanced users can override it by
setting `A3VR_HEAD_ROTATION_GAIN` between `0.10` and `1.50` before launching.
Comfort mono is submitted once as a compositor-owned surface shared by both eyes. The
default `stable-v9` profile preserves the protected runtime's exact `25.4 x 14.3` surface
at a distance of `5.0` during gameplay. When Arma displays its cursor, the compositor
automatically narrows that surface to `9.5` while preserving the capture aspect ratio, so
menus and launch screens fit in view. This camera baseline is intentionally independent
from weapon and controller experiments. `A3VR_MONO_SCREEN_WIDTH`,
`A3VR_MONO_SCREEN_HEIGHT`, `A3VR_MONO_SCREEN_DISTANCE`, and `A3VR_UI_SCREEN_WIDTH`
remain available for deliberate overrides.

The launcher calibrates the active Arma profile to `fovTop=1.2` and
`fovLeft=2.1333333`, preserving the exact 16:9 relationship used by the 1920x1080
capture. It creates a one-time `.a3vr-pre-fov` backup beside the profile before changing
it. Right-controller aim defaults to `420` counts/radian and smooth turn to `300`
counts/second to avoid the previous over-sensitive movement.

The first-person combat path uses Arma's native soldier weapon and native ViewPilot
animation. The right controller drives the authoritative soldier aim through Arma input;
the trigger fires that same weapon. No detached visual weapon is created, so attachments,
optics, recoil, muzzle effects and projectiles cannot diverge from what the player holds.
The artificial body recess is disabled. Suppressing torso and limbs without suppressing
the native weapon requires render-level ViewPilot filtering and is intentionally kept
separate from weapon positioning.

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

See [ROADMAP.md](ROADMAP.md) for the planned tracked-hand, holster and physical
inventory work.
