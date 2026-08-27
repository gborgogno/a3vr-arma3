# A3VR roadmap after 1.0.0

The 1.0.0 release establishes the current hybrid boundary: Arma remains
authoritative for gameplay while OpenXR, presentation, motion input, and local
visual proxies provide the VR layer.

## Shipped foundation

- [x] Experimental per-eye RTT gameplay presentation and complete-frame UI.
- [x] FreeTrack headset pose and OpenXR controller input.
- [x] Config-driven controller-absolute weapon proxy.
- [x] Native ammo, cadence, projectile, damage, sound, reload, and fire-state
  synchronization.
- [x] Best-effort muzzle, cartridge, magazine, ammunition-box, and belt visuals.
- [x] Analog locomotion, smooth turn, stance control, footsteps, and haptics.
- [x] Controller chords and conflict-free in-game settings access.
- [x] Map/inventory proxy transitions and physical-mouse ownership for
  configuration, Zeus, Eden, and custom dialogs.
- [x] One official-Launcher workflow for DLC and other mod presets.

## Next priorities

- [x] Remove the packaged Meta runtime pin and add SteamVR/Vive, PICO, and
  generic OpenXR controller bindings.
- [ ] Complete the v17 live compatibility matrix across SteamVR, VDXR,
  Pimax/PICO, and other OpenXR headset/controller routes.
- [ ] Add deterministic regression scenarios for campaign UI/context handoff.
- [ ] Expand config-driven weapon fixtures for unusual P3D axes, ejection
  points, belt selections, shotguns, and scripted fire modes.
- [ ] Improve vehicle/seat/turret controller mappings without overriding native
  mission controls.
- [ ] Investigate a separately packaged physical-optics path that cannot create
  duplicate cameras or weapons in the core mod.
- [ ] Add optional OpenXR hand-joint support only after a redistributable,
  correctly rigged hand asset and safe fallback exist.
- [ ] Add Authenticode signing and Arma PBO key signing when release
  infrastructure is available.

## Non-negotiable constraints

- The real Arma unit remains authoritative for inventory, ballistics, damage,
  collision, score, AI identity, and mission ownership.
- Generic support must be config-driven; a single weapon/DLC must never become
  the global implementation.
- Experimental presentation paths require a rollback and in-headset comfort
  validation before becoming defaults.
- Automated native tests are not presented as proof of SQF, headset, weapon, or
  campaign behavior.
