# A3VR Hybrid 1.0.0

This is the first stable-numbered A3VR Hybrid release. It consolidates the v16
local-test line: experimental stereo presentation, controller-absolute weapon
control, native gameplay synchronization, controller binds, haptics, locomotion,
UI context handling, and official Launcher integration.

## Highlights

- Experimental per-eye stereo gameplay with complete menu/cinematic framing.
- Config-driven proxy weapons instead of a hard-coded weapon list.
- Native ammo, per-mode cadence, projectile, damage, sound, reload, and fire
  validation remain authoritative.
- Best-effort weapon-relative cartridge, muzzle effect, magazine, box, and belt
  visuals driven by model configuration.
- Analog movement, surface footsteps, smooth turn, stance input, room-scale
  crouch, head/body movement direction, and weapon-only recoil settings.
- OpenXR haptics for shots, damage, and explosions.
- Controller chords for map, inventory, laser/light, bipod, and proxy/native
  control; conflicting `F5`-`F10` shortcuts were removed.
- Physical-mouse ownership for start/configuration/Zeus/Eden/custom dialogs;
  supported map/inventory UI retains the software cursor and guide ray.
- One official-Launcher flow for all DLC and mod presets. No DLC-specific start
  script is required.
- Repeatable tag packaging, immutable CI/dependency pins, SHA-256 release
  assets, secret scanning, static analysis, and Microsoft Defender scanning.

## Important limitations

- This remains an experimental Arma-to-OpenXR bridge, not a native engine VR
  renderer. Stop if stereo causes discomfort.
- PiP must remain enabled. Magnified core optics, independent hands/arms, and
  manual VR reloads are not included.
- Modded weapon effects, belt/magazine selections, model axes, and custom
  campaign UI are config-dependent and cannot be guaranteed universally.
- Vehicles and mission/mod-specific actions may require keyboard and mouse.
- BattlEye, protected multiplayer, Authenticode signing, and PBO signatures are
  not supported in this release.

See `README.md` for installation, every built-in controller binding, settings,
compatibility notes, troubleshooting, security behavior, and the full known-
limitations list.
