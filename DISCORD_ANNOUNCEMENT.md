# A3VR Hybrid VR — Public Alpha 1.13.1-alpha.1

I am opening the first public alpha of **A3VR**, an experimental hybrid VR
bridge for Arma 3. It adds OpenXR headset presentation, 6DoF head tracking,
right-controller motion aiming and useful controller binds while keeping
Arma's native weapon, attachments, muzzle effects and projectiles.

**What works**
- 6DoF head tracking and right-hand motion aiming
- Left-stick movement and sprint
- Fire, ADS, reload, grenade, fire mode, interact and weapon swap
- Right-stick smooth turning and stand/crouch input
- Official Launcher support alongside other mods/DLCs
- Sharp comfort-mono profile with 4K internal rendering

**Meta Touch binds**
- Right trigger: fire
- Right grip: ADS
- Right A: reload
- Right B: grenade
- Right stick click: fire mode
- Left stick: move/strafe; click: sprint
- Right stick horizontal: smooth turn
- Right stick up/down: stand/crouch
- Left X: interact
- Left Y: primary/sidearm swap
- F8: recenter; F9: motion-aim toggle; F10: VR UI mode

**Tested setup**
Meta Quest/Air Link + S.O.G. Prairie Fire, CBA_A3, ACE, Zeus Enhanced,
Suppress, Align, Immerse and True Death. These are not hard dependencies.
Action Menu radial was tested, but I currently recommend leaving it disabled
because its Backspace/menu binds can conflict with VR input.

**Alpha warnings / known issues**
- This is a hybrid bridge, not native per-eye stereo VR.
- The sharp profile intentionally leaves moderate black borders.
- No independent physical hands, manual reload or physical inventory yet.
- Vehicles, Zeus/editor navigation, scopes and UI pointing are experimental.
- Full stance cycling through prone is not reliable yet.
- Arma has many contextual shortcuts, so keyboard and mouse are still strongly
  recommended together with the VR controllers.
- Disable BattlEye and do not join protected multiplayer servers. The native
  DLL/PBO files are not multiplayer-signed.
- Stop immediately if you experience nausea, headache or eye strain.

Please report your headset/runtime, GPU, mission, loaded mods and exact steps
when reporting a bug.
