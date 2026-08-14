# A3VR

**Current public test build: 1.13.1-alpha.1.**

A3VR is an experimental hybrid OpenXR bridge for 64-bit Arma 3. It presents
the game's D3D11 output in a headset, publishes headset movement through
Arma's FreeTrack-compatible input path and maps OpenXR controllers to native
Arma controls. It does **not** require VorpX.

This is an early community alpha, not a native VR port and not an official
Bohemia Interactive product. The initial release prioritizes functional head
tracking, comfort, compatibility and correct native weapon behavior. Full
VR-grade 6DoF camera behavior, independent hands and stereo rendering remain
in development.

## Quick start

1. Subscribe through the Steam Workshop, or extract the release so that the
   complete `@A3VR_Hybrid` directory is available to the Arma 3 Launcher.
2. Start the headset and select the OpenXR runtime you intend to use.
3. In the official Arma 3 Launcher, enable **A3VR - Arma 3 Hybrid VR**. Disable
   every older or duplicate A3VR variant.
4. Disable BattlEye. The native bridge is not signed for protected multiplayer.
5. In Arma's controller/device settings, make sure FreeTrack is enabled when
   it is listed.
6. Start the game normally. Press `F8` once in game to recenter. If the right
   controller does not move the aim, press `F9` once.

The addon starts the OpenXR runtime bridge automatically, so a separate script
is not required for the bridge itself. The FOV/graphics profile is different:
subscribing to the Workshop item and enabling it in the Launcher does **not**
apply that profile automatically. With Arma closed, run
`START_A3VR_LAUNCHER.cmd` from the mod directory once, or apply the settings
manually. The supplied script creates backups before changing the Arma profile.

## Bindings, FreeTrack and FOV setup

- VR-controller mappings are built into the A3VR runtime. A Steam Input profile
  is not required.
- The mappings send Arma's native mouse, keyboard and controller actions. They
  assume the relevant default Arma bindings; customized bindings can cause an
  action to stop matching its documented VR button.
- FreeTrack must still be enabled manually in Arma's controller/device settings.
- Loading the Workshop addon starts A3VR, but does not execute the external
  FOV/graphics configuration script.
- Run `START_A3VR_LAUNCHER.cmd` with Arma closed to apply the supplied FOV and
  graphics profile, then continue through the official Launcher. Reapply it if
  Arma or another mod later replaces those profile values.
- For manual configuration, see the community guide
  [How to increase FOV in ARMA](https://steamcommunity.com/sharedfiles/filedetails/?id=1731376270).
  It is an external reference, not an A3VR dependency; back up the profile
  before making manual changes.

Keyboard and mouse should remain available because Arma has many contextual
commands that do not yet have VR bindings.

## Runtime compatibility

- **Validated:** Meta Quest over Air Link using Meta OpenXR.
- **Community-reported:** VDXR can work, but remains under evaluation.
- **Not yet validated:** Virtual Desktop through SteamVR, native SteamVR
  headsets and Pimax.

Only one application can own the active OpenXR session. If the headset shows
no image, confirm that the intended runtime is active before starting Arma and
close other VR applications that may already own the session.

## What “hybrid” means

A3VR adds OpenXR presentation, headset tracking and controller input around
Arma's existing renderer and animation systems. The compatibility default is
**comfort-mono**: one game surface is submitted to both eyes. It provides a
stable binocular image and head-tracked spatial cues, but it is not native
per-eye stereoscopic rendering and does not provide true binocular depth.

Head rotation and translation are transported through Arma's six-axis
FreeTrack path. Correct VR-scale translation, camera constraints and broader
hardware compatibility are still being refined, so the current 6DoF support
should be considered work in progress.

## Common questions and troubleshooting

### The image appears, but head tracking does not work

- Enable FreeTrack in Arma's controller/device settings.
- Make sure only `@A3VR_Hybrid` is loaded; do not combine it with legacy
  `@A3VR` or another VR bridge.
- Press `F8` after entering the game.

### Head tracking works, but controller aiming does not

- Wake both controllers before starting Arma.
- Press `F9` once to enable motion aiming.
- Test without controller-remapping or radial-menu mods before reporting a
  binding problem.

### The image looks too close or has black borders

The game FOV and the OpenXR presentation surface both affect apparent scale.
The comfort profile intentionally accepts moderate borders to reduce zoom and
retain clarity. Avoid combining multiple A3VR/FOV overrides while diagnosing
the problem.

### Is this true stereo VR?

Not in the current public alpha. Both eyes receive the same comfort-mono game
surface. Native per-eye rendering requires deeper engine-level camera and
render work and is being investigated separately.

### Can it be used in multiplayer?

Use it locally or only on servers that explicitly allow client-side native
modifications. Keep BattlEye disabled and do not join protected servers.

## Current features

- OpenXR headset presentation.
- Six-axis headset pose through Arma's FreeTrack input path; full VR-grade
  6DoF behavior remains in development.
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
| Right B | Throw selected grenade (`G`) |
| Left trigger | Vault / step over (`V`) and index-finger input |
| Left grip | Toggle Action Menu radial wheel (`~`) |
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

Each deliberate right-stick vertical flick changes one stance level: stand,
crouch or prone. Return the stick to center before the next step. In menus,
map, inventory, Zeus and the supported Action Menu radial wheel, point with the right controller. A cyan
cursor marks the actual click position; the trigger clicks and the right stick
scrolls. No VR button sends Escape or opens the pause menu. On foot, right
stick up selects stand and down selects crouch. In vehicles the vertical axis
controls view pitch instead, while the horizontal axis retains smooth turn.
In Zeus, the left stick moves the camera. The default smooth-turn rate is
`620` counts/second and the trigger uses a
low-threshold hysteresis (`0.22` press / `0.12` release) for a quicker response.

F9 remains an emergency keyboard-only motion-aim toggle for vehicle testing.
Magnified and engine-driven PiP optics still use right grip because Arma only
activates those render paths through its native optics camera.

## Architecture

- `A3VRRuntime_v30.exe` owns the OpenXR session, tracks the headset and
  controllers, submits frames and publishes FreeTrack data.
- `A3VRHybridCore_x64.dll` is loaded by Arma, captures the D3D11 backbuffer and
  exchanges tracking/render data with the runtime through shared memory.
- The small SQF addon starts the bridge and exposes the current OpenXR sample
  as `missionNamespace getVariable "A3VRHybrid_tracking"`.

OpenXR and MinHook are fetched from pinned upstream commits during the CMake
configure step; generated build trees and third-party installers are not
committed.

## Player requirements

- Windows 10/11 x64.
- 64-bit Arma 3.
- An active OpenXR runtime and connected headset.
- FreeTrack enabled in Arma's controller/device settings.
- BattlEye disabled.

## Build requirements

- Visual Studio 2022 C++ Build Tools and CMake 3.24+ to build.
- Arma 3 Tools/Addon Builder to package the PBO.

## Build and test

```powershell
.\scripts\build.ps1 -Configuration Release
```

The script configures CMake, builds `A3VRHybridCore_x64.dll` and
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
packages an installable `@A3VR_Hybrid` with `a3vr_hybrid.pbo`, and publishes a ZIP plus
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
older `@A3VR` Stable build disabled when using `@A3VR_Hybrid`. Version 1.12.1+
uses unique DLL, PBO, CfgPatches, CfgFunctions and mission-variable names so
the official launcher can distinguish both installations, but two VR render
bridges still cannot safely run inside the same Arma process.

### VR graphics quality

The packaged launcher applies a reversible `Quality` preset by default. It
captures Arma at 2560x1440, raises shadow quality and distance, improves terrain
and object detail, and reduces excessive sharpening that can shimmer in a
headset. The original `Arma3.cfg` and player profile are copied to
`*.a3vr-pre-vr-quality` before the first change. Run
`scripts\set-a3vr-profile.ps1 -GraphicsPreset Balanced` for a lighter
2304x1296 preset on slower GPUs.

For a direct command-line launch, pass a semicolon-separated list:

```powershell
.\scripts\launch-a3vr.ps1 -AdditionalMods "@CBA_A3;@ace;@RHSUSAF"
```

Absolute Workshop mod paths are also accepted. A3VR is always placed first in
the resulting `-mod` list.

## Extension commands

```sqf
"A3VRHybridCore" callExtension "version";
"A3VRHybridCore" callExtension "start";
"A3VRHybridCore" callExtension "status";
"A3VRHybridCore" callExtension "capture";
private _sample = parseSimpleArray ("A3VRHybridCore" callExtension "pose");
"A3VRHybridCore" callExtension "probe";
```

The `pose` result keeps its existing fields and appends a five-value
left-finger curl array ordered thumb, index, middle, ring and pinky.
Controller-derived curls are an approximation; true independent joints
require optical hand tracking.

The F7 hand is deliberately a line-art calibration proxy. It verifies the
wrist position, axes, scale and finger inputs without replacing or moving
Arma's weapon. The small red, green and blue lines show hand right, forward
and up respectively. A skinned P3D glove replaces this proxy after calibration.

Head rotation defaults to a comfort-oriented `0.42` gain and is limited to 70 degrees
horizontally and 50 degrees vertically, preventing pole flips and upside-down camera states.
Advanced users can override the gain by
setting `A3VR_HEAD_ROTATION_GAIN` between `0.10` and `1.50` before launching.
Comfort mono is submitted once as a compositor-owned surface shared by both eyes. The
default profile uses one compositor-owned `10.0 x 5.625` surface at a distance of `2.0`
during gameplay, shared unchanged by both eyes. This protected comfort-mono path avoids
per-eye projection warping and binocular view mismatch. In UI context, the compositor
uses a `3.8`-wide quad while preserving the capture aspect ratio, so
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
The default `140` mm forward viewpoint offset keeps the native head/neck opening behind
the near plane while preserving Arma's authoritative ViewPilot hands, weapon, attachments,
muzzle effects and projectiles. It is disabled automatically inside vehicles and can be
overridden with `A3VR_BODY_RECESS_MM`.

For large mod sets, A3VR does not require an interaction addon. CBA_A3 + ACE3
and Zeus Enhanced remain compatible, but their additional actions currently use
their own keyboard bindings. The experimental controller modifier layer was removed
because a held or noisy left grip could suppress core locomotion and combat controls.

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

## Inspiration

A3VR was inspired in part by an experimental Arma 3 VR demonstration published
approximately nine years ago:

<https://www.youtube.com/watch?v=I1UzLh-WVVw>

That prototype showed that meaningful headset and motion-controller interaction
could be explored despite the limitations of Real Virtuality 4. A3VR is a
separate modern OpenXR implementation, not a continuation of that project.
