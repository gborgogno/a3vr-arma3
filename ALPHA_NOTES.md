# A3VR 1.13.1-alpha.1

Public testing build of the A3VR hybrid OpenXR bridge for Arma 3.

## Highlights

- 6DoF headset tracking through FreeTrack.
- Right-controller motion aiming with Arma's native weapon path.
- Controller movement, fire, ADS, reload, fire mode, grenade, weapon swap,
  interaction, sprint, smooth turning and stand/crouch input.
- Sharp comfort-mono profile using a 17.5 x 9.84375 surface at 5 m.
- 3840x2160 internal Ultra preset with a 1920x1080 borderless capture/UI.
- Automatic runtime startup from the official Arma 3 Launcher.
- Meta OpenXR runtime override when installed; other headsets fall back to the
  system OpenXR runtime.

## Important alpha limitations

- This is a hybrid bridge, not native per-eye stereo VR.
- Moderate black borders are intentional in the sharp profile.
- No independent physical hands, manual reloads or physical inventory.
- Vehicle input, Zeus/editor navigation, scopes and UI pointing remain
  experimental.
- Stand/crouch is available; full stance cycling through prone is not reliable.
- Keyboard and mouse are recommended for Arma's many contextual commands.
- Disable BattlEye. Native DLL/PBO files are not multiplayer-signed.
- Stop immediately if VR discomfort occurs.

## Tested companion setup

Meta Quest/Air Link, S.O.G. Prairie Fire, CBA_A3, ACE, Zeus Enhanced,
Suppress, Align, Immerse and True Death. Action Menu radial was evaluated but
is excluded from the recommended preset due to input conflicts.
