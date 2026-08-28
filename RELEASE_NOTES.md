# A3VR Hybrid v17.2 development build

v17.2 is an incremental build on top of v17.1. It retains the complete v17.1
SteamVR/OpenXR path, DXGI compatibility fallback, audio routing and head-roll
stabilization. SteamVR support is not reintroduced or replaced in this build.

The v17.2 changes are limited to captured-pose reprojection, higher-resolution
stereo presets, typed controller grip bindings and automatic selection of the
already-supported SteamVR runtime when SteamVR is open.

The last published stable release remains 1.0.1 until v17.2 passes live headset
validation and is explicitly approved for release.

## Previous published release: 1.0.1

This patch release expands the v17 OpenXR path beyond the Meta runtime and
fixes the black headset image observed through SteamVR. It keeps the packaged
runtime selection neutral so the same mod can follow Meta OpenXR, SteamVR,
VDXR, Pimax OpenXR, PICO OpenXR, WMR OpenXR, or another active Windows runtime.

## Highlights

- Reports the active OpenXR runtime name and version in A3VR status output.
- Adds controller bindings for Oculus Touch, Valve Index, Vive, WMR, PICO,
  HTC Cosmos/Focus 3, and the Khronos simple-controller fallback.
- Accepts compatible DXGI UNORM/sRGB swapchain variants instead of requiring
  an exact format match. This fixes the SteamVR black-image failure where Arma
  supplied DXGI format 28 and SteamVR exposed compatible format 29.
- Detects SteamVR whether it is selected globally or through the optional local
  runtime override and applies the Steam Streaming Speakers/Microphone to the
  Arma profile before launch. Existing profile values are backed up first.
- Locates SteamVR audio logs from the selected runtime manifest, including
  Steam libraries installed outside the default Program Files directories.
- Includes an OpenXR compatibility matrix and a neutral runtime template in the
  installable package.

## Validation recorded for this release

- Clean x64 Release build and automated native tests.
- Release archive, PBO contents, version metadata, and SHA-256 checksum.
- Live image and head-tracking startup through SteamVR/OpenXR 2.16.7 on a Meta
  Quest 3S, including the DXGI 28-to-29 compatibility fallback.

## Important limitations

- SteamVR controller feel, haptics, automatic audio routing, head-roll warping,
  and 3DoF motion-controller behavior still require headset acceptance tests.
- Other headset/runtime routes remain implemented but live-test pending.
- This is an experimental Arma-to-OpenXR bridge, not a native engine VR
  renderer. Stop if stereo causes discomfort.
- PiP must remain enabled. Magnified core optics, independent hands/arms, and
  manual VR reloads are not included.
- BattlEye, protected multiplayer, Authenticode signing, and PBO signatures are
  not supported in this release.

See `README.md` and `docs/OPENXR_COMPATIBILITY.md` for installation, controller
bindings, test scope, troubleshooting, and the complete known limitations.
