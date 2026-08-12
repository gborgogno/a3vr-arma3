# A3VR interaction roadmap

The interaction layer must preserve Arma's native inventory, ballistics and
multiplayer authority. Visual proxies should represent interactions; they must
not become a second, conflicting weapon simulation.

## Phase 1 — tracking foundation (v24)

- Decouple headset rotation from right-controller mouse aim.
- Publish left-hand 6DoF pose.
- Publish controller-derived thumb/index/grip curls without changing the
  existing tracking-array indices.

## Phase 2 — visible left hand

- Create or license a redistributable P3D hand mesh with a small finger
  skeleton and neutral/point/grip poses.
- Drive the wrist from the OpenXR left-hand pose.
- Drive the index from trigger, the grip fingers from squeeze and the thumb
  from capacitive touch where available.
- Keep the hand local-only and non-authoritative.

## Phase 3 — optical hand joints

- Add optional `XR_EXT_hand_tracking` support.
- Publish all OpenXR hand joints when the active runtime supports them.
- Fall back cleanly to controller-derived curls when optical tracking is not
  available or controllers are held.

## Phase 4 — body interaction zones

- Shoulder/back zone selects or holsters long guns.
- Hip zone selects or holsters the sidearm.
- Chest zones expose magazines, grenades and selected accessories as local
  visual proxies generated from the actual Arma loadout.
- Add spatial hysteresis and deliberate grip gestures to prevent accidental
  activation during normal movement.

## Phase 5 — manual weapon actions

- Magazine grab validates the selected magazine against the native weapon.
- Magazine insertion triggers Arma's authoritative reload action and animation.
- Charging/bolt gesture provides visual feedback where the weapon supports it.
- Grenade grab maps to Arma's native throwable selection and release.

## Constraints

- Vanilla Arma does not expose arbitrary per-finger pose control for the
  soldier model; a dedicated hand proxy and animations are required.
- Controller inputs cannot provide five truly independent fingers. Optical
  tracking or hardware-specific skeletal input is required for that fidelity.
- Generic support for every modded weapon requires config-driven discovery and
  native Arma actions, never a hard-coded weapon list.
