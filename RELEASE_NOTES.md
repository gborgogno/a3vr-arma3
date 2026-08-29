# A3VR Hybrid 1.0.2

This release stabilizes the stereo presentation path used by the
controller-absolute VR proxy. It keeps the runtime-neutral OpenXR selection
from 1.0.1, so Meta OpenXR, SteamVR, VDXR, Pimax OpenXR, PICO OpenXR, WMR, and
other conformant runtimes continue to be selected by Windows rather than by a
packaged machine-specific override.

## Highlights

- Stamps each completed Arma backbuffer with the latest valid per-eye OpenXR
  poses associated with that captured frame.
- Submits controller-absolute proxy gameplay from the captured local-space
  pose, allowing the active OpenXR compositor to reproject the older image to
  the current headset pose.
- Refreshes the pose stamp for every presented frame even when the shared D3D11
  texture handle remains unchanged.
- Limits the new path to the VR proxy. Native motion, vehicles, menus, and
  cinematics retain the established view-space presentation path.
- Leaves addon/SQF gameplay, HUD framing, FOV profiles, controller bindings,
  audio routing, and runtime selection unchanged from the main baseline.

## Validation recorded for this release

- Clean x64 Release build and automated native tests.
- Release archive, PBO contents, version metadata, neutral runtime template,
  and SHA-256 checksum.
- Static verification that no Meta, SteamVR, VDXR, Pimax, or PICO runtime path
  is hard-coded into the installable package.

## Important limitations

- The automated tests validate native code and packaging; they do not prove
  headset comfort or live behavior on every OpenXR runtime.
- The captured-pose path specifically targets duplicate/dragged imagery during
  head movement in VR proxy gameplay. Stop immediately if stereo causes eye
  strain, divergence, nausea, or discomfort.
- A3VR remains an experimental bridge over Arma's rendered output, not a native
  engine VR renderer. PiP must remain enabled.
- BattlEye, protected multiplayer, Authenticode signing, and PBO signatures are
  not supported in this release.

See `README.md` and `docs/OPENXR_COMPATIBILITY.md` for installation,
controller bindings, test scope, troubleshooting, and known limitations.
