# A3VR 1.14.0-alpha.1

Public testing build of the A3VR hybrid OpenXR bridge for Arma 3.

## Highlights

- Increased right-controller motion-aim response so the native weapon and
  soldier body follow controller rotation more closely.
- Increased smooth-turn speed and added dedicated vertical vehicle
  camera/turret input.
- Added progressive stand, crouch and prone cycling with one deliberate
  right-stick flick per stance level.
- Added physical crouch detection from headset height, with hysteresis to
  prevent stance flicker.
- Improved native interaction input for doors and vehicle actions.
- Added reliable game, UI, Zeus and vehicle context detection without allowing
  stale menu state to disable locomotion or motion aiming.
- Restored the approved sharp comfort profile: wide FOV, 17.5 x 9.84375 surface
  at 5 m, 3840x2160 internal rendering and 1920x1080 borderless output.
- Fixed automatic startup when a Steam Workshop directory contains square
  brackets such as `[Public Alpha]`.
- The public package now follows the system's active OpenXR runtime instead of
  forcing a Meta-specific installation path.

## Important alpha limitations

- This remains a hybrid comfort-mono bridge, not native per-eye stereo VR.
- Moderate black borders are expected in the sharp comfort profile.
- Full room-scale locomotion and independent physical hands are not available.
- Manual reloads, physical inventory, scopes, Zeus navigation and the VR UI
  cursor remain experimental or incomplete.
- Keyboard and mouse remain recommended for Arma's contextual commands.
- Disable BattlEye. Native DLL/PBO files are not multiplayer-signed.
- Stop immediately if the image causes nausea, headache or eye strain.

## Tested setup

Meta Quest over Air Link with Meta OpenXR. S.O.G. Prairie Fire, CBA_A3, ACE,
Zeus Enhanced, Suppress, Align, Immerse and True Death were used during local
testing but are not required dependencies.
