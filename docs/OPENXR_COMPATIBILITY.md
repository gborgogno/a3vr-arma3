# OpenXR runtime compatibility

A3VR v1.0.1 (v17 test line) follows the active Windows OpenXR runtime by default. It does not
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
