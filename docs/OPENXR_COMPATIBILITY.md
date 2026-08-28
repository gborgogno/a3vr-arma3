# OpenXR runtime compatibility

A3VR v17.2 inherits the complete v17.1 OpenXR compatibility path. It follows
the active Windows OpenXR runtime by default and does not
require a vendor-specific API and it does not select Meta, SteamVR, VDXR,
Pimax, or PICO automatically. Select one runtime before starting Arma.

## Intended routes

| Headset or transport | OpenXR route | Built-in controller profile |
| --- | --- | --- |
| Meta Quest with Air/Quest Link | Meta OpenXR | Oculus Touch |
| Meta Quest with Virtual Desktop | VDXR or SteamVR OpenXR | Oculus Touch or the profile emulated by SteamVR |
| Valve Index | SteamVR OpenXR | Valve Index |
| HTC Vive wands | SteamVR OpenXR | HTC Vive Controller |
| Pimax | Pimax OpenXR or SteamVR OpenXR | Profile exposed or emulated by that runtime, commonly Index/Vive |
| PICO Neo 3 / PICO 4 | PICO OpenXR, VDXR, or SteamVR OpenXR | Native ByteDance PICO profile when exposed; otherwise the profile emulated by the runtime |
| PICO Ultra | PICO OpenXR | Native PICO Ultra profile when exposed |
| Windows Mixed Reality | WMR OpenXR | Microsoft Motion Controller |
| Other OpenXR devices | Active vendor runtime | Khronos Simple Controller fallback for pose, fire, reload, interact, and haptics |

The presence of a binding is not headset proof. A runtime may emulate a
different interaction profile, and controller pose, button labels, haptics,
swapchain formats, reprojection, and peripheral distortion still require a
live test on that route.

## Runtime selection

The packaged `a3vr-runtime.ini` contains an empty `runtime=` value. In that
state, the Khronos loader uses the active Windows OpenXR runtime. This is the
recommended configuration.

For isolated troubleshooting, `runtime=` may contain the absolute path to one
installed runtime JSON manifest. The override affects only the A3VR child
runtime process. Do not distribute a package with a machine-specific path.

The A3VR status string reports the loaded runtime name and version after the
OpenXR instance is created. Include that status in compatibility reports.

`START_A3VR.cmd` automatically selects SteamVR when SteamVR is already open,
even if Meta or another runtime remains the Windows default. Use
`START_A3VR_STEAMVR.cmd` to force this route; it starts SteamVR when necessary
and scopes `XR_RUNTIME_JSON` only to A3VR, without changing the global Windows
OpenXR setting.

## v1.0.1/v17 acceptance test

Test each route independently and record:

- headset, controllers, GPU, connection method, and OpenXR runtime/version;
- headset pose and recentering;
- left/right controller pose and weapon alignment;
- fire, ADS/grip, locomotion, turning, reload, interact, and settings modifier;
- haptics for shot, damage, and explosion;
- stereo image, swapchain creation, menu image, latency, and clean shutdown.

Do not mark a route supported from a successful build or from static binding
inspection alone. Use **implemented, live test pending** until the complete
headset test passes.

## v17.1 roll experiment

Gameplay stereo compensates the HMD's relative roll in the submitted OpenXR
eye poses because Arma's FreeTrack cameras intentionally receive yaw and pitch,
but no roll. This keeps the rendered horizon and the compositor pose consistent.
Set `roll_stabilization=0` in `a3vr-motion.ini` to restore the v17 behavior for
an A/B comparison. The status string reports `roll=stabilized` or `roll=legacy`.

## v17.2 quality and motion experiment

The quality preset uses a 2560x1280 side-by-side backbuffer, providing
1280x1280 pixels per eye, and raises both Arma RTT cameras to 2048x2048. The
`StereoPerformance` profile restores the previous 1920x960 capture when the
higher-resolution path is too expensive. Raising Arma sampling above 100% does
not increase the final per-eye transport dimensions and may instead reduce the
frame rate.

Use `START_A3VR.cmd` for the 1280x1280-per-eye quality preset. If the two 2048
RTT cameras cannot hold a stable frame rate, use `START_A3VR_PERFORMANCE.cmd`;
it selects the performance preset automatically without manual profile edits.

Each captured gameplay frame is tagged with the yaw/pitch orientation used by
Arma. The OpenXR projection is submitted in local space from that captured pose
so the runtime can compensate rotation between game capture and headset
display. Set `captured_pose_reprojection=0` in `a3vr-motion.ini` to restore the
legacy head-locked path. The status string reports the effective source/eye
dimensions and `reprojection=captured` or `reprojection=legacy`.

The controller bindings use the typed OpenXR component paths: Touch, Touch Pro,
Touch Plus, PICO, Focus 3 and Index grips use `squeeze/value`; Vive wands and
Windows Mixed Reality use `squeeze/click`. The runtime status also reports the
active right-controller interaction profile so SteamVR emulation can be
identified from a live test instead of guessed from the headset model.
