# A3VR Hybrid

**Current published release: `1.0.1`**

**Current development line: `v17.2` (directly inherits `v17.1`)**

A3VR Hybrid is an experimental OpenXR bridge for 64-bit Arma 3. It presents
Arma's D3D11 output in a headset, publishes headset motion through Arma's
FreeTrack-compatible input path, maps OpenXR motion controllers to native game
input, and provides an optional controller-absolute weapon proxy.

It does **not** require VorpX and is not a native engine VR port. Gameplay
stereo is produced with two Arma render-to-texture cameras; menus and
cinematics use one complete binocular surface so interface controls are not
split between the eyes. Stop immediately if you experience nausea, headache,
eye strain, image divergence, or other visual discomfort.

This is an unofficial community project and is not affiliated with Bohemia
Interactive.

## Release 1.0 highlights

- Experimental left/right stereo presentation with synchronized UI/gameplay
  context switching and a complete menu/cinematic frame.
- Six-axis headset tracking through Arma's FreeTrack input path.
- Right- or left-controller aiming, head- or body-relative movement, analog
  locomotion, smooth turning, progressive stance input, and room-scale crouch.
- A config-driven VR weapon proxy generated from the equipped weapon,
  attachments, magazine, textures, materials, muzzle, and selected fire mode.
- Native player inventory, loaded-ammo count, per-mode cadence, projectile,
  damage, sound, reload state, and fire validation remain authoritative.
- Best-effort support for configured muzzle flash/smoke, cartridge ejection,
  detachable magazines, ammunition boxes, and belt animation sources.
- Native semi-auto, burst, full-auto, shotgun, launcher, rifle, pistol, and
  machine-gun definitions are discovered instead of using a fixed weapon list.
- The real player remains responsible for movement, gravity, collision,
  damage, score, AI identity, inventory, and mission ownership.
- Proxy cleanup and native-control fallback around vehicles, death, respawn,
  Team Switch, remote control, cinematics, map, inventory, Zeus, Eden, and
  blocking dialogs.
- Optional objective and living-squad markers in the proxy camera.
- OpenXR haptics for firing, incoming damage, and explosions.
- Surface-aware footsteps and focus-independent proxy locomotion.
- Direct controller chords for map, inventory, laser/light, bipod, and
  proxy/native weapon control.
- A controller-accessible A3VR settings panel; former `F5`-`F10` shortcuts were
  removed to avoid conflicts with Arma's native function keys.
- Capture-safe software cursor and guide ray for supported controller UI.
  Start screens, configuration dialogs, Zeus, Eden, and custom DLC dialogs are
  intentionally controlled by the physical mouse.
- Automatic runtime startup when the mod is loaded through the official Arma 3
  Launcher. No DLC-specific start script is required.
- Reversible stereo graphics/FOV profile with backups of changed Arma files.

## What is not included

- A native engine VR renderer.
- Independent physical hands, arm IK, optical hand tracking, or manual
  magazine/bolt interactions.
- Core PiP/depth optics. Native ADS is the fallback for magnified scopes.
- Guaranteed compatibility with every modded weapon, scripted campaign UI,
  vehicle, controller layout, or OpenXR runtime.
- BattlEye compatibility, multiplayer signatures, or permission to use native
  modifications on protected servers.

## Requirements

- Windows 10 or 11, x64.
- 64-bit Arma 3.
- A working OpenXR headset/runtime.
- Arma's FreeTrack controller enabled when it appears in the controller list.
- BattlEye disabled.
- Keyboard and mouse available for Arma's contextual and mod-specific actions.

The primary development environment is Meta Quest over Air Link using Meta
OpenXR. VDXR has worked in community tests. SteamVR-native headsets, Virtual
Desktop through SteamVR, Pimax, Valve Index, and Windows Mixed Reality remain
experimental unless explicitly listed in a release test report.

## Install and start

1. Download `A3VR-Hybrid-v1.0.1.zip` and its adjacent `.sha256` file from the
   GitHub release.
2. Verify the ZIP hash, then extract the complete `@A3VR_Hybrid` directory.
3. Start the headset and activate the intended Windows OpenXR runtime.
4. In the official Arma 3 Launcher, choose **Mods > Mod local** and select the
   extracted `@A3VR_Hybrid` directory.
5. Enable A3VR together with the desired DLC and other mods in the same Launcher
   preset. Disable every older A3VR variant and disable BattlEye.
6. Enable FreeTrack in Arma's controller/device settings if it is listed.
7. Click **Play** in the official Launcher. Once in gameplay, hold the left
   grip to open A3VR settings and select **Recenter HMD + Aim**.

The addon starts `A3VRRuntime_v31.exe` automatically. It uses the active Windows
OpenXR runtime and does not force a vendor-specific runtime or DLC preset.
The runtime name and version are included in A3VR's status after initialization.
See [the v1.0.1/v17 OpenXR compatibility matrix](docs/OPENXR_COMPATIBILITY.md) for
SteamVR, Virtual Desktop/VDXR, Pimax, PICO, Vive, Index, WMR, and test status.

`START_A3VR.cmd` and `START_A3VR_LAUNCHER.cmd` are optional helpers. With Arma
closed, they apply the reversible stereo profile and open the official Launcher;
they do not start a separate SOG, Prairie Fire, Spearhead, or other DLC build.

## Controller bindings

The table below describes the Meta Touch labels. Valve Index and Windows Mixed
Reality differences follow it. A customized Arma keyboard/mouse layout may
prevent a simulated native key from matching the action shown in parentheses.

| Input | Gameplay action |
| --- | --- |
| Headset | FreeTrack head rotation and translation |
| Right controller movement | Aim the equipped weapon |
| Right trigger | Fire |
| Right grip | Hold native ADS/optics when enabled in A3VR settings |
| Right A | Reload (`R`) |
| Right B | Throw selected grenade (`G`) |
| Right thumbstick horizontal | Analog smooth turn |
| Right thumbstick up/down | Raise/lower one stance level; vehicle/turret pitch in vehicles |
| Right thumbstick click | Change fire mode (`F`); Enter in controller-capable UI |
| Left controller movement | Aim when left-handed aim is selected |
| Left thumbstick | Analog move and strafe |
| Left thumbstick click | Sprint; middle-click in controller-capable UI |
| Left trigger | Vault/step over (`V`) |
| Left X | Interact/default action (`Space`) |
| Left Y | Switch primary weapon/sidearm |
| Left grip, hold 0.65 seconds | Open/close A3VR settings |

### Left-grip chords

Hold the left grip, press the second control, then release both. These chords
are edge-triggered so the underlying reload, fire-mode, grenade, or weapon-swap
action is not also sent.

| Chord | Action |
| --- | --- |
| Left grip + Right A | Toggle equipped laser or flashlight (`L`) |
| Left grip + Right thumbstick click | Deploy/retract weapon or bipod (`C`) |
| Left grip + Right B | Toggle VR proxy / Native motion |
| Left grip + Left X | Open/close native map (`M`) |
| Left grip + Left Y | Open/close native inventory (`I`) |

No controller binding sends Escape or opens Arma's pause menu.

### Valve Index labels

The trigger, grip, sticks, and stick clicks keep the same roles. Right A reloads,
Right B throws a grenade, Left A interacts, and Left B switches weapon. Apply
the same left-grip chords using those labels.

### Windows Mixed Reality labels and limits

The suggested OpenXR profile maps the right trigger to fire, left trigger to
vault, left/right sticks to movement/turn, left-stick click to sprint, right
menu to reload, right-stick click to fire mode, and left menu to interact.
Right-grip ADS and the left-grip modifier use WMR squeeze clicks. Grenade and
weapon-swap are not assigned by the built-in WMR profile and may require runtime
remapping or keyboard/mouse.

### SteamVR, Vive, Pimax, Virtual Desktop, and PICO

SteamVR can expose Valve Index, Vive wand, Oculus Touch, or another emulated
OpenXR interaction profile depending on the headset and controller setup.
Virtual Desktop may use VDXR directly or SteamVR OpenXR. Pimax may use its
OpenXR runtime or SteamVR OpenXR. PICO Neo 3, PICO 4, and PICO Ultra native
profiles are enabled when the active runtime advertises their OpenXR extension.

The packaged runtime selection is neutral: it follows the active Windows
OpenXR runtime. SteamVR/OpenXR 2.16.7 image and head tracking were exercised on
a Quest 3S; controller, haptics, audio, and the other routes remain live-test
pending until the matching headset/controller acceptance test is recorded.

### Analog locomotion and stance

Left-stick magnitude controls walking speed and returns immediately to neutral
when released. Pushing the stick past the sprint threshold or clicking it runs.
Each deliberate right-stick vertical flick changes one stance level; return the
stick to center before the next change. A head-height drop of about 30 cm after
recenter can also request crouch, with hysteresis to prevent flicker.

## In-game settings

Open settings by holding the left grip for 0.65 seconds or clicking
**A3VR VR SETTINGS** in pause, map, or inventory. The panel itself uses the
physical mouse so motion controls cannot steal focus from configuration.

| Setting | Values | Default |
| --- | --- | --- |
| Gameplay aim | Right controller / Left controller | Right controller |
| Menu pointer | Head gaze / Right controller | Head gaze |
| Smooth turning | Comfort / Normal / Fast | Fast |
| 2D UI scale | Full frame / Larger | Full frame |
| Tracking diagnostic | Off / On | Off each session |
| Movement direction | Head direction / Body direction | Head direction |
| Native ADS on right grip | On / Off | On |
| Proxy HUD / mission markers | Off / On | On |
| Weapon recoil | Off / Comfort / Normal | Normal |
| Weapon control | Native motion / VR proxy | VR proxy |
| Motion aiming | Frozen / Live controller | Live controller |

Settings are saved in the Arma profile except the diagnostic overlay, which is
session-only and always starts disabled.

## Weapon control modes

### VR proxy

The proxy is the controller-absolute mode. It creates a local visual weapon from
the currently equipped class while a hidden native firing path remains tied to
the real unit. The selected muzzle and fire mode provide cadence and ammunition
rules; fire effects are emitted only after a validated native shot consumes
ammo. Empty weapons therefore do not produce proxy muzzle flashes or forced
background reload sounds.

Magazine, box, belt, muzzle-effect, and cartridge animation support is
config-driven and best effort. When a weapon provides standard memory points or
animation sources, effects follow the proxy weapon transform. Unusual P3D axes,
custom scripts, or absent selections can still require weapon-specific support.

### Native motion

Native motion restores Arma's ordinary first-person body, weapon, animations,
and firing. Head tracking and controller-to-mouse aiming remain available. Use
it for vehicles, scripted sequences, unsupported weapons, or diagnosis.

## UI, map, inventory, Zeus, and DLC menus

- Start/loading screens, pause, A3VR settings, Arma configuration screens,
  Zeus, Eden, and focused third-party/DLC dialogs use the physical mouse.
- Map and inventory keep the configured head/controller pointer and their grip
  chords so they can be opened and closed from proxy mode.
- Supported controller UI shows a capture-safe cursor and dotted guide ray;
  right trigger clicks, right stick scrolls, right-stick click accepts, and
  left-stick click sends middle mouse.
- Normal gameplay hides the software cursor and releases UI-only input.
- Campaign and mod UI classification is heuristic. If a scripted display keeps
  control after it visually closes, switch temporarily to Native motion, close
  the display with mouse/keyboard, then return to VR proxy.

The optional proxy HUD mirrors active task destinations and living group
members only. It cannot reproduce every icon made by a mission, ACE, Zeus
Enhanced, or another addon.

## Known limitations

- Stereo RTT is experimental and more expensive than the earlier mono surface.
  PiP must remain enabled. Menus/cinematics temporarily use a single complete
  binocular image rather than independent per-eye UI cameras.
- This release does not make Arma a native VR renderer. Head/body scale, FOV,
  latency, reprojection, and peripheral distortion can vary by runtime and GPU.
- FreeTrack may not appear until the A3VR runtime is running or Arma's controller
  list has been refreshed.
- UI/cinematic detection is heuristic. Custom campaign displays can keep the
  cursor visible, delay proxy activation, or restore gameplay framing late.
- Magnified PiP/depth optics are not implemented in the core release. Use native
  ADS for scopes; physical iron sights can be used without ADS.
- There are no independent hands/arms or manual VR reloads. Reload uses Arma's
  native inventory timing and available model animations.
- Generic weapon support cannot guarantee correct geometry for every addon.
  Nonstandard model axes, memory points, magazines, belt selections, muzzle
  definitions, scripted firing, or shell effects can be missing or misaligned.
- Cartridge ejection and muzzle smoke are visual mirrors of validated native
  fire. They are disabled when a safe weapon-relative origin cannot be found;
  they never replace native ammunition or ballistics.
- Belt and detachable-magazine visibility depends on the weapon exposing usable
  animation sources/selections. Static or custom-scripted models may not animate.
- Native projectiles, hit transfer, and proxy cleanup are experimental around
  missions that replace damage, inventory, ownership, or camera behavior.
- Door, ladder, vehicle, medical, ACE, and mission-specific interactions can
  still require keyboard/mouse.
- Vehicles use native control; mapping is incomplete across all seats/turrets.
- The PBO and native binaries are not multiplayer-signed. Do not use A3VR with
  BattlEye or on protected servers.
- Only one application can own the active OpenXR session. Other VR games or
  overlays can prevent A3VR from presenting.
- The native binaries are not Authenticode-signed. Verify the published SHA-256
  before running a downloaded package.

## Troubleshooting

### Flat or head-locked image

- Confirm the intended OpenXR runtime is active and both controllers are awake.
- Load only one A3VR variant.
- Enable FreeTrack in Arma and use **Recenter HMD + Aim** in gameplay.
- If FreeTrack is absent, exit Arma, run `START_A3VR_LAUNCHER.cmd`, and launch
  again through the official Launcher.

### Movement/fire stops or a cursor remains in gameplay

- Close the visible dialog with the physical mouse or keyboard.
- Toggle Native motion, then return to VR proxy after gameplay resumes.
- Check the RPT for `[A3VR] Game context` messages and enable the session-only
  tracking diagnostic only while collecting a report.

### Image feels too close, blurred, split, or uncomfortable

- Stop playing before further adjustment.
- Recenter once in normal gameplay, not during a menu or cinematic.
- Confirm no second A3VR/FOV override or stereo injector is active.
- Try the `Balanced` profile with Arma closed:

```powershell
.\scripts\set-a3vr-profile.ps1 -GraphicsPreset Balanced
```

## Other mods and DLC

Load A3VR, DLC, and other mods together in one official Launcher preset. A3VR
does not depend on CBA, ACE, SOG Prairie Fire, Spearhead, or a DLC-specific
starter. Compatibility with a combination is not guaranteed; reproduce binding,
UI, or weapon issues with A3VR alone before reporting them.

Never enable legacy `@A3VR` and `@A3VR_Hybrid` together.

## Architecture, privacy, and security

- `A3VRRuntime_v31.exe` owns the OpenXR session, tracks the HMD/controllers,
  submits frames, publishes FreeTrack, and emits local input.
- `A3VRHybridCore_x64.dll` is loaded by Arma (or preloaded by the local runtime
  into a process verified as `arma3_x64.exe`), hooks the D3D11 presentation
  path, captures the backbuffer, and exchanges state through local named shared
  memory/events.
- `a3vr_hybrid.pbo` starts the bridge, classifies game/UI context, draws local
  cursor/markers, and manages the weapon proxy.

A3VR has no telemetry, account login, updater, remote-control service, or
gameplay network client. The runtime does use behavior that security products
can consider sensitive: local DLL preloading, a D3D11 hook, local shared memory,
FreeTrack publication, and local keyboard/mouse input through Windows APIs.
These are required bridge functions and are documented in
[`SECURITY.md`](SECURITY.md).

OpenXR SDK, MinHook, and the release PBO packer are fetched from immutable
upstream object IDs. GitHub Actions used for release are pinned to immutable
commits. Release ZIPs are accompanied by a SHA-256 file.

## Build and test

Requirements: Visual Studio 2022 C++ Build Tools and CMake 3.24 or newer.

```powershell
.\scripts\build.ps1 -Configuration Release
```

This builds `A3VRHybridCore_x64.dll`, `A3VRRuntime_v31.exe`, the OpenXR probe,
and the automated math/extension tests. Local PBO packaging uses Arma 3 Tools:

```powershell
.\scripts\package.ps1 -Configuration Release
```

GitHub tag builds package the same active addon tree with the pinned open-source
`4d4a5852/a3lib.py` revision.

Automated tests validate native math, input-state behavior, and extension
startup/version reporting. They do **not** prove headset comfort, every SQF path,
weapon/DLC compatibility, or live Arma behavior; those require in-game testing.

## Extension diagnostics

```sqf
"A3VRHybridCore" callExtension "version";
"A3VRHybridCore" callExtension "start";
"A3VRHybridCore" callExtension "status";
"A3VRHybridCore" callExtension "capture";
private _sample = parseSimpleArray ("A3VRHybridCore" callExtension "pose");
"A3VRHybridCore" callExtension "probe";
```

Runtime/SQF diagnostics are written to Arma's normal RPT log. Before posting a
complete profile or log, remove Windows account names, local paths, server
addresses, and mod lists you do not want to disclose.

## License and attribution

A3VR Hybrid is released under the [Arma Public License Share Alike
(APL-SA)](LICENSE). See [NOTICE](NOTICE) and
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for attribution and
third-party license details.

The presentation architecture was inspired by the open-source OpenOVR project.
That project is not bundled and is not required at runtime.
