/*
    Controller-absolute weapon proxy.

    The real player remains the gameplay authority for movement, inventory,
    ammunition, fire mode, damage and score. When its exact weapon state is
    available, a parked hidden native rig performs the shot at the configured
    weapon cadence. FiredMan assigns its projectile and native-config visual
    effects to the controller muzzle, then mirrors loaded ammunition back.

    Movement still uses the real Arma unit and its collisions. While grounded,
    the addon writes controller-relative horizontal velocity to that unit;
    airborne motion, gravity and collision response remain engine-owned.

    The rig and the visual holder are aligned from their real model proxy and
    muzzle transforms. No mouse motion, learned shot offset or hard-coded
    per-weapon orientation is used.
*/
if (!hasInterface) exitWith {};

// The function may be recompiled/restarted from the debug console while a
// mission is still running. Remove the previous per-frame handlers before
// resetting their state, otherwise two proxy owners render the weapon and
// fight over the camera on every frame.
if (!isNil "A3VRHybrid_proxyEachFrame" && {
    A3VRHybrid_proxyEachFrame isEqualType 0} && {
    A3VRHybrid_proxyEachFrame >= 0}) then {
    removeMissionEventHandler ["EachFrame", A3VRHybrid_proxyEachFrame];
};
if (!isNil "A3VRHybrid_proxyLaserDrawEH" && {
    A3VRHybrid_proxyLaserDrawEH isEqualType 0} && {
    A3VRHybrid_proxyLaserDrawEH >= 0}) then {
    removeMissionEventHandler ["Draw3D", A3VRHybrid_proxyLaserDrawEH];
};
if (!isNil "A3VRHybrid_proxyMarkerDrawEH" && {
    A3VRHybrid_proxyMarkerDrawEH isEqualType 0} && {
    A3VRHybrid_proxyMarkerDrawEH >= 0}) then {
    removeMissionEventHandler ["Draw3D", A3VRHybrid_proxyMarkerDrawEH];
};
// A debug-console restart can replace the namespace before normal cleanup.
// Restore the authoritative unit's original automatic-reload setting first.
if (!isNil "A3VRHybrid_proxyOwner" && {
    !isNull A3VRHybrid_proxyOwner} && {
    !isNil "A3VRHybrid_proxyOriginalReloadEnabled"}) then {
    A3VRHybrid_proxyOwner enableReload
        A3VRHybrid_proxyOriginalReloadEnabled;
};

A3VRHybrid_proxyEnabled = true;
A3VRHybrid_proxyActive = false;
A3VRHybrid_proxyCamera = objNull;
A3VRHybrid_proxyOwner = objNull;
A3VRHybrid_proxyRig = objNull;
A3VRHybrid_proxyRigFiredEH = -1;
A3VRHybrid_proxyRigReady = false;
A3VRHybrid_proxyPlayerFiredEH = -1;
A3VRHybrid_proxyVisual = objNull;
A3VRHybrid_proxyGeometry = objNull;
A3VRHybrid_proxyAttachments = [];
A3VRHybrid_proxyVisualComposite = false;
A3VRHybrid_proxyVisualSignature = "";
A3VRHybrid_proxyWeaponClass = "";
A3VRHybrid_proxyWeaponState = [];
A3VRHybrid_proxyWeaponModel = "";
A3VRHybrid_proxyModelForward = [0, 1, 0];
A3VRHybrid_proxyModelUp = [0, 0, 1];
A3VRHybrid_proxyModelMuzzle = [0, 0.55, 0];
A3VRHybrid_proxyVisualMount = [];
A3VRHybrid_proxyRigMount = [];
A3VRHybrid_proxyBaseMuzzlePosition = [0, 0, 0];
A3VRHybrid_proxyMuzzlePosition = [0, 0, 0];
A3VRHybrid_proxyMuzzleDirection = [0, 1, 0];
A3VRHybrid_proxyMuzzleUp = [0, 0, 1];
A3VRHybrid_proxyMuzzleClearanceLog = "";
A3VRHybrid_proxySuppressed = false;
A3VRHybrid_proxyFlashSelections = [];
A3VRHybrid_proxyFlashAnimations = [];
A3VRHybrid_proxyFlashGeneration = 0;
A3VRHybrid_proxyFlashUntil = -10;
A3VRHybrid_proxyReloadActive = false;
A3VRHybrid_proxyReloadStart = 0;
A3VRHybrid_proxyReloadDuration = 2.4;
A3VRHybrid_proxyReloadPhase = 0;
A3VRHybrid_proxyReloadAnimations = [];
A3VRHybrid_proxyReloadMagazineClass = "";
A3VRHybrid_proxyReloadSawNativePhase = false;
A3VRHybrid_proxyReloadFallback = false;
A3VRHybrid_proxyReloadBaseline = [];
A3VRHybrid_proxyNormalFov = 1.1811123;
A3VRHybrid_proxyLoadoutSignature = "";
A3VRHybrid_proxyNextSync = 0;
A3VRHybrid_proxyLastButtons = 0;
A3VRHybrid_proxyLastShot = 0;
A3VRHybrid_proxyNextShotAt = 0;
A3VRHybrid_proxyAcceptedShotSequence = 0;
A3VRHybrid_proxyLastFireProfile = "";
A3VRHybrid_proxyLastDryFireAt = -10;
A3VRHybrid_proxyFirePending = false;
A3VRHybrid_proxyBurstShotsRemaining = 0;
A3VRHybrid_proxyMovementAction = "";
A3VRHybrid_proxyAmmoVisualState = [];
A3VRHybrid_proxyAmmoVisualLayout = "";
A3VRHybrid_proxyModelAmmoState = ["", 0, 1];
A3VRHybrid_proxyEjectMemoryLog = "";
A3VRHybrid_proxyBeltFeedPhase = 0;
A3VRHybrid_proxyBeltAnimationLog = "";
A3VRHybrid_proxyBeltAnimations = [];
A3VRHybrid_proxyGunParticleLog = "";
A3VRHybrid_proxyNativeEffectLog = "";
A3VRHybrid_proxyCasings = [];
A3VRHybrid_proxyLastDamageHapticAt = -10;
A3VRHybrid_proxyReferenceHeadPosition = [0, 0, 0];
A3VRHybrid_proxyReferenceRight = [1, 0, 0];
A3VRHybrid_proxyReferenceForward = [0, 1, 0];
A3VRHybrid_proxyReferenceUp = [0, 0, 1];
A3VRHybrid_proxyWorldRight = [1, 0, 0];
A3VRHybrid_proxyWorldForward = [0, 1, 0];
A3VRHybrid_proxyWorldUp = [0, 0, 1];
A3VRHybrid_proxyWorldYaw = 0;
A3VRHybrid_proxyCalibrated = false;
A3VRHybrid_proxyRecoilPitch = 0;
A3VRHybrid_proxyRecoilPitchVelocity = 0;
A3VRHybrid_proxyRecoilYaw = 0;
A3VRHybrid_proxyRecoilYawVelocity = 0;
A3VRHybrid_proxyRecoilBack = 0;
A3VRHybrid_proxyRecoilBackVelocity = 0;
A3VRHybrid_proxyHandsSelectionLog = "";
A3VRHybrid_proxyHandVisuals = [];
A3VRHybrid_proxyHandSignature = "";
A3VRHybrid_proxyNextCombatVisibility = 0;
A3VRHybrid_proxyAITarget = objNull;
A3VRHybrid_proxyAITargetGroup = grpNull;
A3VRHybrid_proxyPlayerDamageEH = -1;
A3VRHybrid_proxyLastNativeDamageAt = -10;
A3VRHybrid_proxyLastNativeDamageShooter = objNull;
A3VRHybrid_proxyLastNativeDamageAmmo = "";
A3VRHybrid_proxyHostileFiredUnits = [];
A3VRHybrid_proxyIncomingProjectiles = [];
A3VRHybrid_proxyAccessoryEnabled = false;
A3VRHybrid_proxyAccessoryClass = "";
A3VRHybrid_proxyState = "NATIVE";
A3VRHybrid_proxyMotionEnabled = missionNamespace getVariable [
    "A3VRHybrid_proxyMotionEnabled", true];
A3VRHybrid_proxyFrozenTarget = [];
A3VRHybrid_proxyTransitionGeneration = 0;
A3VRHybrid_proxyLastStateReason = "initialization";
A3VRHybrid_proxyLastInvariantCheck = 0;
A3VRHybrid_proxyLastInteraction = -10;
A3VRHybrid_proxyLastVehicle = objNull;
A3VRHybrid_proxyLifecycleUnit = objNull;
A3VRHybrid_proxyOriginalCollisionFlag = true;
A3VRHybrid_proxyOriginalHidden = false;
A3VRHybrid_proxyOriginalReloadEnabled = true;
A3VRHybrid_proxyWasMoving = false;
A3VRHybrid_proxyLastToggleAt = -10;
A3VRHybrid_proxyVehicleEntryPendingUntil = -10;
A3VRHybrid_proxyUiRequestPendingUntil = -10;
A3VRHybrid_proxyMapChordLatched = false;
A3VRHybrid_proxyInventoryChordLatched = false;
A3VRHybrid_proxyPreviousHud = [];
A3VRHybrid_proxyNextHudRefresh = 0;
A3VRHybrid_proxyHudForced = false;
A3VRHybrid_fnc_proxyToReference = {
    params ["_vector"];
    [
        _vector vectorDotProduct A3VRHybrid_proxyReferenceRight,
        _vector vectorDotProduct A3VRHybrid_proxyReferenceForward,
        _vector vectorDotProduct A3VRHybrid_proxyReferenceUp
    ]
};

A3VRHybrid_fnc_proxyToWorld = {
    params ["_vector"];
    (A3VRHybrid_proxyWorldRight vectorMultiply (_vector # 0)) vectorAdd
    (A3VRHybrid_proxyWorldForward vectorMultiply (_vector # 1)) vectorAdd
    (A3VRHybrid_proxyWorldUp vectorMultiply (_vector # 2))
};

A3VRHybrid_fnc_proxyTransformVector = {
    params ["_right", "_forward", "_up", "_vector"];
    (_right vectorMultiply (_vector # 0)) vectorAdd
    (_forward vectorMultiply (_vector # 1)) vectorAdd
    (_up vectorMultiply (_vector # 2))
};

A3VRHybrid_fnc_proxySetState = {
    params ["_next", ["_reason", "unspecified"]];
    private _previous = A3VRHybrid_proxyState;
    A3VRHybrid_proxyState = _next;
    A3VRHybrid_proxyLastStateReason = _reason;
    if (_previous isNotEqualTo _next) then {
        A3VRHybrid_proxyTransitionGeneration =
            A3VRHybrid_proxyTransitionGeneration + 1;
        diag_log format [
            "[A3VR][State] %1 -> %2 reason=%3 generation=%4",
            _previous, _next, _reason,
            A3VRHybrid_proxyTransitionGeneration
        ];
    };
};

/*
    CBA is optional.  During Zeus remote control CBA_fnc_currentUnit is the
    most reliable authority; vanilla scenarios commonly publish the same unit
    through BIS_fnc_moduleRemoteControl_unit.  Proxy mode deliberately
    suspends while a remote unit is controlled instead of binding stale player
    references or leaving two weapons behind.
*/
A3VRHybrid_fnc_proxyControlledUnit = {
    private _unit = player;
    if (!(isNil "CBA_fnc_currentUnit")) then {
        private _candidate = call CBA_fnc_currentUnit;
        if (_candidate isEqualType objNull && {!isNull _candidate}) then {
            _unit = _candidate;
        };
    } else {
        private _candidate = missionNamespace getVariable [
            "BIS_fnc_moduleRemoteControl_unit", objNull];
        if (_candidate isEqualType objNull && {!isNull _candidate}) then {
            _unit = _candidate;
        };
    };
    _unit
};

/* Keep room-scale head translation, but stop the rendered eye just before
   solid geometry.  This never moves the Arma body or disables positional
   tracking; only the proxy camera's local offset is constrained. */
A3VRHybrid_fnc_proxyClipHeadPosition = {
    params ["_bodyEye", "_desired"];
    private _delta = _desired vectorDiff _bodyEye;
    private _horizontal = [_delta # 0, _delta # 1, 0];
    if (vectorMagnitude _horizontal > 0.85) then {
        _horizontal = vectorNormalized _horizontal vectorMultiply 0.85;
        _desired = _bodyEye vectorAdd [
            _horizontal # 0, _horizontal # 1,
            ((_delta # 2) max -0.75) min 0.75
        ];
    };
    private _hits = lineIntersectsSurfaces [
        _bodyEye, _desired, player, A3VRHybrid_proxyRig,
        true, 1, "VIEW", "FIRE", true
    ];
    if (count _hits isEqualTo 0) exitWith {_desired};
    private _direction = _desired vectorDiff _bodyEye;
    if (vectorMagnitude _direction < 0.001) exitWith {_bodyEye};
    _direction = vectorNormalized _direction;
    private _safe = ((_hits # 0) # 0) vectorDiff
        (_direction vectorMultiply 0.055);
    _safe
};

/*
    The weapon object is visual-only and must never participate in character
    physics.  Earlier builds ray-clipped the grip and barrel against scene
    geometry.  A controller pose resting on the edge of that ray test could
    alternate between clipped/unclipped every frame, which looked like a
    duplicated or flashing weapon.  Preserve the tracked pose and constrain
    only the degenerate case where the controller is inside the HMD.
*/
A3VRHybrid_fnc_proxyClipWeaponTarget = {
    params ["_cameraPosition", "_origin", "_forward", "_weapon"];
    private _corrected = +_origin;
    private _fromHead = _corrected vectorDiff _cameraPosition;
    if (vectorMagnitude _fromHead < 0.11) then {
        private _safeDirection = if (vectorMagnitude _fromHead > 0.001) then {
            vectorNormalized _fromHead
        } else {
            vectorNormalized _forward
        };
        _corrected = _cameraPosition vectorAdd
            (_safeDirection vectorMultiply 0.11);
    };
    _corrected
};

A3VRHybrid_fnc_proxyFindInteractionVehicle = {
    params ["_eye", "_direction"];
    private _candidate = cursorObject;
    if (!isNull _candidate && {_candidate isKindOf "AllVehicles"} &&
        {!(_candidate isKindOf "Man")} &&
        {player distance _candidate <= 5.5}) exitWith {_candidate};

    private _vehicles = nearestObjects [
        player, ["LandVehicle", "Air", "Ship"], 5.5, true];
    private _best = objNull;
    private _bestScore = -1000;
    {
        if (!isNull _x && {alive _x}) then {
            private _toward = (getPosWorld _x) vectorDiff _eye;
            private _distance = vectorMagnitude _toward;
            if (_distance > 0.01) then {
                private _facing = (vectorNormalized _toward)
                    vectorDotProduct _direction;
                private _score = _facing - (0.035 * _distance);
                if (_facing > 0.28 && {_score > _bestScore}) then {
                    _best = _x;
                    _bestScore = _score;
                };
            };
        };
    } forEach _vehicles;
    _best
};

A3VRHybrid_fnc_proxyEnterVehicle = {
    params ["_vehicle"];
    if (isNull _vehicle || {vehicle player isNotEqualTo player}) exitWith {false};
    private _crew = fullCrew [_vehicle, "", true];
    private _entry = [];
    {
        private _occupant = _x param [0, objNull];
        private _role = toLower (_x param [1, ""]);
        if (isNull _occupant && {_role in [
            "driver", "gunner", "commander", "cargo", "turret"]}) exitWith {
            _entry = +_x;
        };
    } forEach _crew;
    if (count _entry isEqualTo 0) exitWith {false};

    private _role = toLower (_entry param [1, ""]);
    // Release the full-screen proxy camera before Arma changes the player's
    // parent object.  Waiting for the next EachFrame left one disconnected
    // camera frame and could make vehicle head tracking appear lost.
    A3VRHybrid_proxyVehicleEntryPendingUntil = diag_tickTime + 3.0;
    if (A3VRHybrid_proxyActive) then {
        ["vehicle-entry"] call A3VRHybrid_fnc_proxyCleanup;
    };
    switch (_role) do {
        case "driver": {player action ["GetInDriver", _vehicle];};
        case "gunner": {player action ["GetInGunner", _vehicle];};
        case "commander": {player action ["GetInCommander", _vehicle];};
        case "turret": {
            player action ["GetInTurret", _vehicle,
                _entry param [3, []]];
        };
        default {
            player action ["GetInCargo", _vehicle,
                _entry param [2, -1]];
        };
    };
    A3VRHybrid_proxyLastVehicle = _vehicle;
    diag_log format [
        "[A3VR][Interaction] vehicle entry requested vehicle=%1 role=%2 distance=%3",
        typeOf _vehicle, _role, player distance _vehicle
    ];
    true
};

A3VRHybrid_fnc_proxyDoorIndexFromText = {
    params [["_text", ""]];
    private _digits = [];
    {
        if (_x >= 48 && {_x <= 57}) then {
            _digits pushBack _x;
        } else {
            if (count _digits > 0) exitWith {};
        };
    } forEach (toArray _text);
    if (count _digits isEqualTo 0) exitWith {-1};
    parseNumber (toString _digits)
};

A3VRHybrid_fnc_proxyFindInteractionDoor = {
    params ["_eye", "_direction"];
    private _forward = vectorNormalized _direction;
    if (vectorMagnitude _forward < 0.5) exitWith {[]};
    private _end = _eye vectorAdd (_forward vectorMultiply 5.0);
    private _objects = [];
    {
        private _object = _x param [2, objNull];
        if (!isNull _object) then {_objects pushBackUnique _object;};
    } forEach (lineIntersectsSurfaces [
        _eye, _end, player, A3VRHybrid_proxyRig,
        true, 8, "VIEW", "FIRE", true
    ]);
    if (!isNull cursorObject) then {_objects pushBackUnique cursorObject;};
    {
        _objects pushBackUnique _x;
    } forEach (nearestTerrainObjects [
        ASLToAGL _end, ["BUILDING", "HOUSE"], 3.0, false, true
    ]);

    private _best = [];
    private _bestScore = 1e6;
    {
        private _building = _x;
        if (!isNull _building &&
            {_building isKindOf "House" ||
             {_building isKindOf "Building"}}) then {
            private _actionsRoot = configFile >> "CfgVehicles" >>
                typeOf _building >> "UserActions";
            private _actions = if (isClass _actionsRoot) then {
                configProperties [_actionsRoot, "isClass _x", true]
            } else {[]};
            {
                private _actionName = configName _x;
                private _positionName = getText (_x >> "position");
                private _statement = getText (_x >> "statement");
                private _description = getText (_x >> "displayName");
                private _search = toLower format ["%1 %2 %3 %4",
                    _actionName, _positionName, _statement, _description];
                if ((_search find "door") >= 0 &&
                    {_positionName isNotEqualTo ""}) then {
                    private _local = _building selectionPosition
                        [_positionName, "Memory"];
                    private _world = _building modelToWorldVisualWorld _local;
                    private _toward = _world vectorDiff _eye;
                    private _along = _toward vectorDotProduct _forward;
                    private _nearest = _eye vectorAdd
                        (_forward vectorMultiply _along);
                    private _offRay = _world distance _nearest;
                    private _radius = (getNumber (_x >> "radius")) max 0.8;
                    if (_along > -0.25 && {_along < 5.5} &&
                        {_offRay <= (_radius min 1.8)}) then {
                        private _index = [_positionName] call
                            A3VRHybrid_fnc_proxyDoorIndexFromText;
                        if (_index < 0) then {
                            _index = [_actionName] call
                                A3VRHybrid_fnc_proxyDoorIndexFromText;
                        };
                        if (_index < 0) then {
                            _index = [_statement] call
                                A3VRHybrid_fnc_proxyDoorIndexFromText;
                        };
                        private _score = _offRay + (0.015 * (_along max 0));
                        if (_index > 0 && {_score < _bestScore}) then {
                            _best = [_building, _index, _world];
                            _bestScore = _score;
                        };
                    };
                };
            } forEach _actions;
        };
    } forEach _objects;
    _best
};

A3VRHybrid_fnc_proxyToggleDoor = {
    params ["_building", "_index"];
    if (isNull _building || {_index <= 0}) exitWith {false};
    private _disabled = _building getVariable [
        format ["bis_disabled_Door_%1", _index], 0];
    private _locked = if (_disabled isEqualType true) then {_disabled} else {
        _disabled isEqualType 0 && {_disabled > 0}
    };
    if (_locked) exitWith {false};

    // Vanilla and CUP-compatible buildings expose this conventional source.
    // Do not enumerate animation sources here: animationSourceNames is not
    // available in every retail Arma 3 parser and would abort the whole proxy
    // loop before the weapon could be created.
    private _source = format ["Door_%1_sound_source", _index];
    private _phase = _building animationSourcePhase _source;
    private _target = [1, 0] select (_phase > 0.5);
    [_building, _index, _target] call BIS_fnc_door;
    diag_log format [
        "[A3VR][Interaction] door toggled building=%1 index=%2 source=%3 phase=%4 target=%5",
        typeOf _building, _index, _source, _phase, _target
    ];
    true
};

A3VRHybrid_fnc_proxyInteract = {
    params ["_eye", "_direction"];
    if (diag_tickTime - A3VRHybrid_proxyLastInteraction < 0.22) exitWith {};
    A3VRHybrid_proxyLastInteraction = diag_tickTime;
    private _vehicle = [_eye, _direction] call
        A3VRHybrid_fnc_proxyFindInteractionVehicle;
    if (!isNull _vehicle) then {
        [_vehicle] call A3VRHybrid_fnc_proxyEnterVehicle;
    } else {
        private _door = [_eye, _direction] call
            A3VRHybrid_fnc_proxyFindInteractionDoor;
        if (count _door >= 2) then {
            _door params ["_building", "_index"];
            // Give Arma's native Default Action one frame to handle the door.
            // The fallback only runs if its animation phase did not change,
            // avoiding an open-then-close double activation.
            private _source = format ["Door_%1_sound_source", _index];
            private _before = _building animationSourcePhase _source;
            [_building, _index, _source, _before] spawn {
                params ["_building", "_index", "_source", "_before"];
                uiSleep 0.08;
                if (!isNull _building &&
                    {abs ((_building animationSourcePhase _source) -
                        _before) < 0.01}) then {
                    [_building, _index] call
                        A3VRHybrid_fnc_proxyToggleDoor;
                };
            };
        };
    };
    // The runtime simultaneously holds Arma's native Space/Default Action.
    // Ladders and mission-specific actions therefore keep their native
    // conditions; doors and vehicle entry also receive controller-ray
    // fallbacks because Arma otherwise tests the hidden soldier's aim ray.
};

A3VRHybrid_fnc_proxyDumpState = {
    private _controlled = call A3VRHybrid_fnc_proxyControlledUnit;
    private _cameraPosition = if (isNull A3VRHybrid_proxyCamera) then {[]} else {
        getPosWorld A3VRHybrid_proxyCamera
    };
    private _proxyPosition = if (isNull A3VRHybrid_proxyVisual) then {[]} else {
        getPosWorld A3VRHybrid_proxyVisual
    };
    diag_log format [
        "[A3VR][Dump] state=%1 enabled=%2 active=%3 motion=%4 reason=%5 generation=%6 player=%7 controlled=%8 owner=%9 alive=%10 vehicle=%11 cameraOn=%12 proxyCamera=%13 weapon=%14 muzzle=%15 mode=%16 stance=%17 damage=%18 damageAllowed=%19 playerPos=%20 cameraPos=%21 weaponPos=%22 tracking=%23",
        A3VRHybrid_proxyState, A3VRHybrid_proxyEnabled,
        A3VRHybrid_proxyActive, A3VRHybrid_proxyMotionEnabled,
        A3VRHybrid_proxyLastStateReason,
        A3VRHybrid_proxyTransitionGeneration, player, _controlled,
        A3VRHybrid_proxyOwner, alive player, vehicle player, cameraOn,
        A3VRHybrid_proxyCamera, currentWeapon player, currentMuzzle player,
        currentWeaponMode player, stance player, damage player,
        isDamageAllowed player, getPosWorld player, _cameraPosition,
        _proxyPosition, count (missionNamespace getVariable [
            "A3VRHybrid_tracking", []])
    ];
    systemChat format [
        "A3VR state: %1 | proxy %2 | motion %3 | unit %4",
        A3VRHybrid_proxyState,
        ["OFF", "ON"] select A3VRHybrid_proxyActive,
        ["OFF", "ON"] select A3VRHybrid_proxyMotionEnabled,
        typeOf _controlled
    ];
};

A3VRHybrid_fnc_proxyValidateState = {
    if (diag_tickTime < A3VRHybrid_proxyLastInvariantCheck) exitWith {};
    A3VRHybrid_proxyLastInvariantCheck = diag_tickTime + 1;
    if (!(missionNamespace getVariable [
        "A3VRHybrid_debugEnabled", false])) exitWith {};
    private _violations = [];
    if (A3VRHybrid_proxyState isEqualTo "PROXY" &&
        {!A3VRHybrid_proxyActive}) then {
        _violations pushBack "PROXY state without active flag";
    };
    if (A3VRHybrid_proxyState isEqualTo "NATIVE" &&
        {A3VRHybrid_proxyActive || {!isNull A3VRHybrid_proxyCamera} ||
         {!isNull A3VRHybrid_proxyVisual}}) then {
        _violations pushBack "NATIVE state retains proxy resources";
    };
    if (A3VRHybrid_proxyActive &&
        {isNull A3VRHybrid_proxyOwner ||
         {!(A3VRHybrid_proxyOwner isEqualTo player)}}) then {
        _violations pushBack "active proxy bound to stale player";
    };
    if (count _violations > 0) then {
        diag_log format ["[A3VR][Invariant] %1", _violations];
    };
};

/* Clip controller-driven proxy velocity against walls before it reaches the
   real player. This path remains reliable even when OpenXR owns window focus. */
A3VRHybrid_fnc_proxyClipMovementVelocity = {
    params ["_velocity"];
    if (isNull player) exitWith {_velocity};

    private _horizontal = [_velocity # 0, _velocity # 1, 0];
    private _speed = vectorMagnitude _horizontal;
    if (_speed < 0.01) exitWith {_velocity};

    private _forward = vectorNormalized _horizontal;
    private _right = vectorNormalized
        (_forward vectorCrossProduct [0, 0, 1]);
    private _base = getPosWorld player;
    private _frameTime = ((diag_deltaTime max 0.016) min 0.10);
    private _castDistance = 0.34 + (_speed * _frameTime * 1.45);
    private _heights = switch (stance player) do {
        case "PRONE": {[0.22, 0.42]};
        case "CROUCH": {[0.25, 0.72, 1.05]};
        default {[0.25, 0.82, 1.42]};
    };
    private _clipped = +_horizontal;

    {
        private _height = _x;
        {
            private _lateral = _x;
            private _start = _base vectorAdd
                (_right vectorMultiply _lateral);
            _start = _start vectorAdd [0, 0, _height];
            _start = _start vectorDiff (_forward vectorMultiply 0.04);
            private _end = _start vectorAdd
                (_forward vectorMultiply _castDistance);
            private _hits = lineIntersectsSurfaces [
                _start, _end, player, A3VRHybrid_proxyRig,
                true, 1, "GEOM", "NONE", true
            ];
            if (count _hits > 0) then {
                private _normal = vectorNormalized ((_hits # 0) # 1);
                // Terrain and walkable slopes keep their native vertical
                // velocity. Only side-facing scene geometry clips motion.
                if (abs (_normal # 2) < 0.72) then {
                    private _toward = _clipped vectorDotProduct _normal;
                    if (_toward < 0) then {
                        _clipped = _clipped vectorDiff
                            (_normal vectorMultiply _toward);
                    };
                };
            };
        } forEach [-0.22, 0, 0.22];
    } forEach _heights;

    [_clipped # 0, _clipped # 1, _velocity # 2]
};

/*
    Recoil is deliberately applied to the controller weapon target, never to
    the HMD camera. The shot adds an impulse; a critically damped spring brings
    the native weapon and hands back to the tracked controller pose.
*/
A3VRHybrid_fnc_proxyAddRecoil = {
    params ["_weapon", "_ammo"];
    private _mode = missionNamespace getVariable [
        "A3VRHybrid_settingRecoil", "normal"];
    if (_mode isEqualTo "off") exitWith {};

    private _ammoConfig = configFile >> "CfgAmmo" >> _ammo;
    private _hit = getNumber (_ammoConfig >> "hit");
    private _indirectHit = getNumber (_ammoConfig >> "indirectHit");
    private _power = (sqrt ((_hit + (0.20 * _indirectHit)) max 1)) * 0.42;
    _power = (_power max 0.65) min 3.4;
    if (_weapon isEqualTo secondaryWeapon player) then {
        _power = (_power * 1.25) min 4.0;
    };
    private _scale = if (_mode isEqualTo "comfort") then {0.55} else {1};
    private _yawImpulse = random [
        -5.5 * _power, 0, 5.5 * _power];

    A3VRHybrid_proxyRecoilPitchVelocity =
        (A3VRHybrid_proxyRecoilPitchVelocity +
        (28 * _power * _scale)) min 220;
    A3VRHybrid_proxyRecoilYawVelocity =
        (A3VRHybrid_proxyRecoilYawVelocity +
        (_yawImpulse * _scale)) max -40 min 40;
    A3VRHybrid_proxyRecoilBackVelocity =
        (A3VRHybrid_proxyRecoilBackVelocity +
        (0.24 * _power * _scale)) min 1.8;
};

A3VRHybrid_fnc_proxyApplyRecoil = {
    params ["_origin", "_forward", "_up"];
    private _dt = (diag_deltaTime max 0.001) min 0.05;

    A3VRHybrid_proxyRecoilPitchVelocity =
        (A3VRHybrid_proxyRecoilPitchVelocity -
        (165 * A3VRHybrid_proxyRecoilPitch * _dt)) *
        ((1 - (10.5 * _dt)) max 0);
    A3VRHybrid_proxyRecoilYawVelocity =
        (A3VRHybrid_proxyRecoilYawVelocity -
        (190 * A3VRHybrid_proxyRecoilYaw * _dt)) *
        ((1 - (12 * _dt)) max 0);
    A3VRHybrid_proxyRecoilBackVelocity =
        (A3VRHybrid_proxyRecoilBackVelocity -
        (210 * A3VRHybrid_proxyRecoilBack * _dt)) *
        ((1 - (13 * _dt)) max 0);

    A3VRHybrid_proxyRecoilPitch =
        (A3VRHybrid_proxyRecoilPitch +
        (A3VRHybrid_proxyRecoilPitchVelocity * _dt)) max -0.4 min 8.5;
    A3VRHybrid_proxyRecoilYaw =
        (A3VRHybrid_proxyRecoilYaw +
        (A3VRHybrid_proxyRecoilYawVelocity * _dt)) max -2.5 min 2.5;
    A3VRHybrid_proxyRecoilBack =
        (A3VRHybrid_proxyRecoilBack +
        (A3VRHybrid_proxyRecoilBackVelocity * _dt)) max 0 min 0.105;

    if ((missionNamespace getVariable [
        "A3VRHybrid_settingRecoil", "normal"]) isEqualTo "off") then {
        A3VRHybrid_proxyRecoilPitch = 0;
        A3VRHybrid_proxyRecoilPitchVelocity = 0;
        A3VRHybrid_proxyRecoilYaw = 0;
        A3VRHybrid_proxyRecoilYawVelocity = 0;
        A3VRHybrid_proxyRecoilBack = 0;
        A3VRHybrid_proxyRecoilBackVelocity = 0;
    };

    private _right = vectorNormalized (_forward vectorCrossProduct _up);
    private _yawForward = vectorNormalized
        ((_forward vectorMultiply (cos A3VRHybrid_proxyRecoilYaw)) vectorAdd
        (_right vectorMultiply (sin A3VRHybrid_proxyRecoilYaw)));
    private _recoilForward = vectorNormalized
        ((_yawForward vectorMultiply
        (cos A3VRHybrid_proxyRecoilPitch)) vectorAdd
        (_up vectorMultiply (sin A3VRHybrid_proxyRecoilPitch)));
    private _recoilUp = vectorNormalized
        ((_up vectorMultiply (cos A3VRHybrid_proxyRecoilPitch)) vectorDiff
        (_yawForward vectorMultiply
        (sin A3VRHybrid_proxyRecoilPitch)));
    private _recoilOrigin = _origin vectorDiff
        (_recoilForward vectorMultiply A3VRHybrid_proxyRecoilBack);
    [_recoilOrigin, _recoilForward, _recoilUp]
};

A3VRHybrid_fnc_proxyApplyConfigAppearance = {
    params ["_object", "_config", ["_label", ""]];
    if (isNull _object || {isNull _config}) exitWith {};

    // createSimpleObject loads the shared P3D but does not apply the weapon
    // class' variant textures automatically. Sand, black, khaki and modded
    // skins therefore need the same hidden-selection overrides declared by
    // their actual CfgWeapons/CfgMagazines class.
    private _selections = getArray (_config >> "hiddenSelections");
    private _textures = getArray (_config >> "hiddenSelectionsTextures");
    {
        if (_x isEqualType "" && {_x isNotEqualTo ""}) then {
            // Some vanilla and modded P3Ds expose only the numeric section,
            // while others require the configured selection name. Apply both
            // views so the derived weapon class wins over the base P3D skin.
            _object setObjectTexture [_forEachIndex, _x];
            if (_forEachIndex < count _selections) then {
                private _name = _selections # _forEachIndex;
                if (_name isEqualType "" && {_name isNotEqualTo ""}) then {
                    _object setObjectTexture [_name, _x];
                };
            };
        };
    } forEach _textures;
    private _materials = getArray (_config >> "hiddenSelectionsMaterials");
    {
        if (_x isEqualType "" && {_x isNotEqualTo ""}) then {
            _object setObjectMaterial [_forEachIndex, _x];
            if (_forEachIndex < count _selections) then {
                private _name = _selections # _forEachIndex;
                if (_name isEqualType "" && {_name isNotEqualTo ""}) then {
                    _object setObjectMaterial [_name, _x];
                };
            };
        };
    } forEach _materials;
    diag_log format [
        "[A3VR] Proxy appearance class=%1 selections=%2 configuredTextures=%3 appliedTextures=%4 configuredMaterials=%5 appliedMaterials=%6",
        _label, _selections, _textures, getObjectTextures _object,
        _materials, getObjectMaterials _object
    ];
};

/*
    Never create a second Man for AI visibility.  A texture-transparent dummy
    is still a real soldier to Arma's renderer and was visible in several
    character models.  The authoritative hidden player is revealed directly
    to legitimate line-of-sight hostiles instead.
*/
A3VRHybrid_fnc_proxyDeleteAITarget = {
    if (!isNull A3VRHybrid_proxyAITarget) then {
        deleteVehicle A3VRHybrid_proxyAITarget;
    };
    A3VRHybrid_proxyAITarget = objNull;
    if (!isNull A3VRHybrid_proxyAITargetGroup) then {
        deleteGroup A3VRHybrid_proxyAITargetGroup;
    };
    A3VRHybrid_proxyAITargetGroup = grpNull;
};

A3VRHybrid_fnc_proxyCreateAITarget = {
    call A3VRHybrid_fnc_proxyDeleteAITarget;
};

A3VRHybrid_fnc_proxyRefreshCombatVisibility = {
    if (diag_tickTime < A3VRHybrid_proxyNextCombatVisibility) exitWith {};
    A3VRHybrid_proxyNextCombatVisibility = diag_tickTime + 0.55;
    if (isNull player || {!alive player}) exitWith {};

    // The real player remains the only gameplay and damage authority.
    if !(isDamageAllowed player) then {
        player allowDamage true;
        diag_log "[A3VR] Real-player damage authority restored";
    };

    private _playerSide = side player;
    private _playerEye = eyePos player;
    {
        if (!isNull _x && {alive _x} && {_x isNotEqualTo player} &&
            {(_x distance player) <= 180} &&
            {((side _x) getFriend _playerSide) < 0.6}) then {
            private _enemyEye = eyePos _x;
            if (!lineIntersects [_enemyEye, _playerEye, _x, player]) then {
                _x reveal [player, 4];
                (group _x) reveal [player, 4];
                [_x] call A3VRHybrid_fnc_proxyTrackHostileShooter;
                _x doTarget player;
                _x doFire player;
                // hideObject removes the target geometry that normally lets
                // AI complete its firing solution.  Give a periodically
                // refreshed positional suppression order as a fallback so a
                // hostile that has already acquired the real player does not
                // stand aiming indefinitely.
                private _lastSuppression = _x getVariable [
                    "A3VRHybrid_proxyLastSuppression", -10];
                if (diag_tickTime - _lastSuppression > 2.25) then {
                    _x setVariable [
                        "A3VRHybrid_proxyLastSuppression", diag_tickTime];
                    _x doSuppressiveFire (getPosASL player);
                };
            };
        };
    } forEach allUnits;
};

/*
    hideObject removes the visual/fire geometry that direct bullets normally
    collide with, although splash damage still reaches the authoritative
    player. Track only bullets fired by confirmed hostile units and test their
    swept frame segment against a compact head/chest/pelvis capsule. Native
    hits delete the projectile first and are left untouched; pass-through hits
    are relayed to the real player with the original shooter as instigator.
*/
A3VRHybrid_fnc_proxyTrackHostileShooter = {
    params ["_unit"];
    if (isNull _unit) exitWith {};
    private _existing = _unit getVariable [
        "A3VRHybrid_proxyIncomingFiredEH", -1];
    if (_existing >= 0) exitWith {};
    private _id = _unit addEventHandler ["FiredMan", {
        params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo",
            "_magazine", "_projectile"];
        if (!A3VRHybrid_proxyActive || {isNull player} ||
            {!alive player} || {isNull _projectile}) exitWith {};
        private _simulation = toLower getText (
            configFile >> "CfgAmmo" >> _ammo >> "simulation");
        if (_simulation isNotEqualTo "shotbullet") exitWith {};
        A3VRHybrid_proxyIncomingProjectiles pushBack [
            _projectile, getPosWorld _projectile, _unit, _ammo,
            diag_tickTime
        ];
    }];
    _unit setVariable ["A3VRHybrid_proxyIncomingFiredEH", _id];
    A3VRHybrid_proxyHostileFiredUnits pushBackUnique _unit;
    diag_log format [
        "[A3VR] Hostile fire tracking unit=%1 side=%2 playerSide=%3",
        typeOf _unit, side _unit, side player
    ];
};

A3VRHybrid_fnc_proxyClearHostileFireTracking = {
    {
        if (!isNull _x) then {
            private _id = _x getVariable [
                "A3VRHybrid_proxyIncomingFiredEH", -1];
            if (_id >= 0) then {
                _x removeEventHandler ["FiredMan", _id];
            };
            _x setVariable ["A3VRHybrid_proxyIncomingFiredEH", -1];
        };
    } forEach A3VRHybrid_proxyHostileFiredUnits;
    A3VRHybrid_proxyHostileFiredUnits = [];
    A3VRHybrid_proxyIncomingProjectiles = [];
};

A3VRHybrid_fnc_proxySegmentDistance = {
    params ["_start", "_end", "_point"];
    private _segment = _end vectorDiff _start;
    private _lengthSquared = _segment vectorDotProduct _segment;
    if (_lengthSquared < 0.000001) exitWith {
        vectorMagnitude (_point vectorDiff _start)
    };
    private _t = ((_point vectorDiff _start) vectorDotProduct _segment) /
        _lengthSquared;
    _t = (_t max 0) min 1;
    private _closest = _start vectorAdd (_segment vectorMultiply _t);
    vectorMagnitude (_point vectorDiff _closest)
};

A3VRHybrid_fnc_proxyRelayIncomingBulletDamage = {
    if (count A3VRHybrid_proxyIncomingProjectiles isEqualTo 0) exitWith {};
    if (isNull player || {!alive player}) exitWith {
        A3VRHybrid_proxyIncomingProjectiles = [];
    };

    private _pelvis = player modelToWorldVisualWorld
        (selectionPosition [player, "pelvis", 0]);
    private _chest = player modelToWorldVisualWorld
        (selectionPosition [player, "spine3", 0]);
    private _head = eyePos player;
    private _capsules = [
        [_pelvis, 0.38, 1.00, "body"],
        [_chest, 0.40, 1.25, "body"],
        [_head, 0.24, 2.15, "head"]
    ];
    private _kept = [];
    {
        _x params ["_projectile", "_previous", "_shooter", "_ammo",
            "_created"];
        if (!isNull _projectile &&
            {(diag_tickTime - _created) <= 4.0}) then {
            private _current = getPosWorld _projectile;
            private _hit = [];
            {
                _x params ["_center", "_radius", "_multiplier",
                    "_zone"];
                if (([_previous, _current, _center] call
                    A3VRHybrid_fnc_proxySegmentDistance) <= _radius) exitWith {
                    _hit = [_multiplier, _zone];
                };
            } forEach _capsules;

            if (count _hit > 0) then {
                private _nativeHandled =
                    (diag_tickTime - A3VRHybrid_proxyLastNativeDamageAt) < 0.12 &&
                    {A3VRHybrid_proxyLastNativeDamageShooter isEqualTo _shooter} &&
                    {A3VRHybrid_proxyLastNativeDamageAmmo isEqualTo _ammo};
                if (_nativeHandled) then {
                    diag_log format [
                        "[A3VR] Incoming bullet already handled by native collision ammo=%1 shooter=%2",
                        _ammo, typeOf _shooter
                    ];
                } else {
                    private _ammoConfig = configFile >> "CfgAmmo" >> _ammo;
                    private _hitValue = getNumber (_ammoConfig >> "hit");
                    private _increment = (((_hitValue max 1) / 70) *
                        (_hit # 0)) max 0.035 min 0.65;
                    private _oldDamage = damage player;
                    private _newDamage = (_oldDamage + _increment) min 1;
                    player setDamage [
                        _newDamage, true, _shooter, _shooter, false];
                    // The scripted camera does not inherit Arma's normal
                    // first-person hit kick.  Keep this deliberately subtle:
                    // enough to register an impact without a violent VR jolt.
                    addCamShake [0.45 + (_increment * 0.8), 0.10, 14];
                    diag_log format [
                        "[A3VR] Incoming bullet relayed ammo=%1 zone=%2 hit=%3 damage=%4->%5 shooter=%6",
                        _ammo, _hit # 1, _hitValue, _oldDamage, _newDamage,
                        typeOf _shooter
                    ];
                    deleteVehicle _projectile;
                };
            } else {
                _x set [1, _current];
                _kept pushBack _x;
            };
        };
    } forEach A3VRHybrid_proxyIncomingProjectiles;
    A3VRHybrid_proxyIncomingProjectiles = _kept;
};

A3VRHybrid_fnc_proxyCalibrate = {
    params ["_head"];
    A3VRHybrid_proxyReferenceHeadPosition = +(_head # 2);
    A3VRHybrid_proxyReferenceForward = vectorNormalized (_head # 3);
    A3VRHybrid_proxyReferenceUp = vectorNormalized (_head # 4);
    A3VRHybrid_proxyReferenceRight = vectorNormalized
        (A3VRHybrid_proxyReferenceForward vectorCrossProduct
        A3VRHybrid_proxyReferenceUp);
    A3VRHybrid_proxyReferenceUp = vectorNormalized
        (A3VRHybrid_proxyReferenceRight vectorCrossProduct
        A3VRHybrid_proxyReferenceForward);

    A3VRHybrid_proxyWorldYaw = getDir player;
    A3VRHybrid_proxyWorldForward = [
        sin A3VRHybrid_proxyWorldYaw, cos A3VRHybrid_proxyWorldYaw, 0];
    A3VRHybrid_proxyWorldRight = [
        cos A3VRHybrid_proxyWorldYaw, -sin A3VRHybrid_proxyWorldYaw, 0];
    A3VRHybrid_proxyWorldUp = [0, 0, 1];
    A3VRHybrid_proxyCalibrated = true;
    diag_log format ["[A3VR] Proxy calibrated yaw=%1 head=%2",
        A3VRHybrid_proxyWorldYaw, A3VRHybrid_proxyReferenceHeadPosition];
};

A3VRHybrid_fnc_proxyStableWeaponState = {
    params ["_state"];
    private _stable = +_state;
    {
        if (_x < count _stable) then {
            private _mag = _stable # _x;
            if (_mag isEqualType [] && {count _mag > 0}) then {
                _stable set [_x, _mag # 0];
            } else {
                if (_x isEqualTo 4 &&
                    {A3VRHybrid_proxyReloadActive} &&
                    {A3VRHybrid_proxyReloadMagazineClass isNotEqualTo ""}) then {
                    _stable set [_x,
                        A3VRHybrid_proxyReloadMagazineClass];
                };
            };
        };
    } forEach [4, 5];
    _stable
};

A3VRHybrid_fnc_proxyBeginReloadVisual = {
    params ["_weapon", "_state", ["_requestedMagazine", ""]];
    private _magazineState = _state param [4, []];
    A3VRHybrid_proxyReloadMagazineClass = _requestedMagazine;
    if (A3VRHybrid_proxyReloadMagazineClass isEqualTo "") then {
        A3VRHybrid_proxyReloadMagazineClass = if (
            _magazineState isEqualType [] && {count _magazineState > 0}
        ) then {_magazineState # 0} else {currentMagazine player};
    };

    private _weaponConfig = configFile >> "CfgWeapons" >> _weapon;
    private _muzzle = currentMuzzle player;
    private _muzzleConfig = if (_muzzle isNotEqualTo "" &&
        {_muzzle isNotEqualTo _weapon} &&
        {isClass (_weaponConfig >> _muzzle)}) then {
        _weaponConfig >> _muzzle
    } else {_weaponConfig};
    private _duration = getNumber (_muzzleConfig >> "magazineReloadTime");
    if (_duration <= 0) then {
        _duration = getNumber (_weaponConfig >> "magazineReloadTime");
    };
    if (_duration <= 0) then {_duration = 2.4;};
    A3VRHybrid_proxyReloadDuration = (_duration max 0.75) min 8;

    A3VRHybrid_proxyReloadAnimations = [];
    A3VRHybrid_proxyReloadBaseline = [];
    if (!isNull A3VRHybrid_proxyVisual) then {
        {
            private _lower = toLower _x;
            private _reloadAnimation =
                ((_lower find "reload") >= 0) ||
                {(_lower find "_rm") >= 0} ||
                {(_lower find "top_cover") >= 0} ||
                {(_lower find "feedtray") >= 0} ||
                {(_lower find "charging_handle") >= 0} ||
                {(_lower find "mag_clipper") >= 0} ||
                {(_lower find "magazine_move") >= 0} ||
                {(_lower find "magazine_rot") >= 0};
            if (_reloadAnimation &&
                {(_lower find "muzzleflash") < 0} &&
                {(_lower find "zasleh") < 0}) then {
                A3VRHybrid_proxyReloadAnimations pushBackUnique _x;
                A3VRHybrid_proxyReloadBaseline pushBack [
                    _x, A3VRHybrid_proxyVisual animationPhase _x];
            };
        } forEach (animationNames A3VRHybrid_proxyVisual);
    };
    A3VRHybrid_proxyReloadActive = true;
    A3VRHybrid_proxyReloadStart = diag_tickTime;
    A3VRHybrid_proxyReloadPhase = 0;
    A3VRHybrid_proxyReloadSawNativePhase = false;
    A3VRHybrid_proxyReloadFallback = false;
    diag_log format [
        "[A3VR] Proxy reload tracking weapon=%1 timeout=%2 magazine=%3 candidates=%4",
        _weapon, A3VRHybrid_proxyReloadDuration,
        A3VRHybrid_proxyReloadMagazineClass,
        A3VRHybrid_proxyReloadAnimations
    ];
};

A3VRHybrid_fnc_proxyUpdateReloadVisual = {
    if (!A3VRHybrid_proxyReloadActive ||
        {isNull A3VRHybrid_proxyVisual}) exitWith {};
    private _elapsed = diag_tickTime - A3VRHybrid_proxyReloadStart;
    private _state = weaponState player;
    private _nativePhase = if (count _state >= 7) then {
        (_state # 6) max 0 min 1
    } else {0};
    if (_nativePhase > 0.0001) then {
        A3VRHybrid_proxyReloadSawNativePhase = true;
        // weaponState exposes magazine reload from 1 to 0. Hand-weapon model
        // controllers expect the inverse, 0 at the start and 1 at the end.
        A3VRHybrid_proxyReloadPhase = 1 - _nativePhase;
    } else {
        if (!A3VRHybrid_proxyReloadSawNativePhase) then {
            // A few DLC reload actions do not publish phase #6 immediately.
            // Keep a duration-based fallback until the native phase appears.
            A3VRHybrid_proxyReloadPhase = ((_elapsed /
                A3VRHybrid_proxyReloadDuration) max 0) min 1;
        };
    };

    private _phase = A3VRHybrid_proxyReloadPhase;
    A3VRHybrid_proxyVisual animateSource [
        "reloadMagazine", _phase, true];
    A3VRHybrid_proxyVisual animateSource [
        "reloadMagazine.0", _phase, true];

    // Raw weapon P3Ds from some DLCs expose the animations but not the
    // CfgWeapons source binding. Detect that case instead of blindly driving
    // every magazine part on every weapon.
    if (!A3VRHybrid_proxyReloadFallback && {_phase >= 0.45} &&
        {count A3VRHybrid_proxyReloadBaseline > 0}) then {
        private _sourceMoved = A3VRHybrid_proxyReloadBaseline findIf {
            abs ((A3VRHybrid_proxyVisual animationPhase (_x # 0)) -
                (_x # 1)) > 0.005
        };
        if (_sourceMoved < 0) then {
            A3VRHybrid_proxyReloadFallback = true;
            diag_log format [
                "[A3VR] Proxy reload source fallback weapon=%1 animations=%2",
                currentWeapon player, A3VRHybrid_proxyReloadAnimations];
        };
    };
    if (A3VRHybrid_proxyReloadFallback) then {
        {
            private _name = _x;
            private _lower = toLower _name;
            private _directPhase = _phase;
            private _late = (_lower find "down") >= 0 ||
                {(_lower find "_end") >= 0} ||
                {(_lower find "bolt_fwd") >= 0} ||
                {(_lower find "safety_off") >= 0};
            private _early = (_lower find "_up") >= 0 ||
                {(_lower find "_begin") >= 0} ||
                {(_lower find "release") >= 0} ||
                {(_lower find "safety_on") >= 0};
            if (_late) then {
                _directPhase = (((_phase - 0.68) / 0.28) max 0) min 1;
            } else {
                if (_early) then {
                    _directPhase = ((_phase / 0.25) max 0) min 1;
                } else {
                    _directPhase = (((_phase - 0.12) / 0.62) max 0) min 1;
                };
            };
            A3VRHybrid_proxyVisual animate [_name, _directPhase, true];
        } forEach A3VRHybrid_proxyReloadAnimations;
    };

    private _complete =
        (A3VRHybrid_proxyReloadSawNativePhase && {_nativePhase <= 0.0001} &&
            {_elapsed > 0.15}) ||
        {_elapsed >= (A3VRHybrid_proxyReloadDuration + 0.10)};
    if (_complete) then {
        {
            A3VRHybrid_proxyVisual animate [_x, 0, true];
        } forEach A3VRHybrid_proxyReloadAnimations;
        A3VRHybrid_proxyVisual animateSource [
            "reloadMagazine", 0, true];
        A3VRHybrid_proxyVisual animateSource [
            "reloadMagazine.0", 0, true];
        A3VRHybrid_proxyReloadActive = false;
        A3VRHybrid_proxyReloadPhase = 0;
        A3VRHybrid_proxyReloadAnimations = [];
        A3VRHybrid_proxyReloadBaseline = [];
        A3VRHybrid_proxyReloadSawNativePhase = false;
        A3VRHybrid_proxyReloadFallback = false;
        A3VRHybrid_proxyReloadMagazineClass = "";
        A3VRHybrid_proxyNextSync = 0;
        diag_log "[A3VR] Proxy reload tracking completed";
    };
};

A3VRHybrid_fnc_proxyCurrentWeaponState = {
    params ["_weapon"];
    private _result = [];
    {
        if (count _x > 0 && {(_x # 0) isEqualTo _weapon}) exitWith {
            _result = +_x;
        };
    } forEach weaponsItems player;
    if (_result isEqualTo []) then {
        _result = [_weapon, "", "", "", [], [], ""];
    };
    while {count _result < 7} do {_result pushBack "";};
    _result
};

/* Return one compatible, non-loaded magazine that actually contains rounds.
   The native reload command still decides whether the operation is legal; this
   preflight prevents an empty trigger press from starting visual tracking. */
A3VRHybrid_fnc_proxyFindReloadMagazine = {
    params ["_weapon", "_muzzle"];
    if (_weapon isEqualTo "" || {_muzzle isEqualTo ""}) exitWith {""};
    private _configMuzzle = _muzzle;
    if (_muzzle isEqualTo _weapon) then {_configMuzzle = "this";};
    private _compatible = compatibleMagazines [_weapon, _configMuzzle];
    if (_compatible isEqualTo [] && {_configMuzzle isNotEqualTo _muzzle}) then {
        _compatible = compatibleMagazines [_weapon, _muzzle];
    };
    private _inventory = magazinesAmmoFull [player, true];
    private _index = _inventory findIf {
        private _class = _x param [0, ""];
        private _rounds = _x param [1, 0];
        private _loaded = _x param [2, false];
        !_loaded && {_rounds > 0} && {_class in _compatible}
    };
    if (_index < 0) then {""} else {(_inventory # _index) # 0}
};

A3VRHybrid_fnc_proxyLoadoutSignature = {
    private _states = [];
    {
        _states pushBack ([_x] call A3VRHybrid_fnc_proxyStableWeaponState);
    } forEach weaponsItems player;
    private _spareMagazines = [];
    {
        if (!(_x param [2, false])) then {
            _spareMagazines pushBack [
                _x param [0, ""], _x param [1, 0],
                _x param [3, 0], _x param [4, ""]
            ];
        };
    } forEach (magazinesAmmoFull [player, true]);
    str [typeOf player, currentWeapon player, currentMuzzle player,
        currentWeaponMode player, _states, _spareMagazines]
};

A3VRHybrid_fnc_proxySelectWeapon = {
    params ["_unit", "_weapon", ["_mode", ""], ["_muzzle", ""]];
    if (isNull _unit || {_weapon isEqualTo ""}) exitWith {};
    if (_muzzle isEqualTo "") then {
        private _muzzles = getArray
            (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
        _muzzle = _weapon;
        if (count _muzzles > 0 && {(_muzzles # 0) isNotEqualTo "this"}) then {
            _muzzle = _muzzles # 0;
        };
    };
    if (_mode isEqualTo "") then {
        _unit selectWeapon _muzzle;
    } else {
        _unit selectWeapon [_weapon, _muzzle, _mode];
    };
};

A3VRHybrid_fnc_proxyApplyRigLoadout = {
    params ["_rig"];
    if (isNull _rig || {isNull player}) exitWith {false};

    // The firing rig carries only the player's currently selected weapon.
    // This prevents an empty launcher from automatically switching the hidden
    // rig to a rifle while the visible/controller weapon is still a launcher.
    private _weapon = currentWeapon player;
    if (_weapon isEqualTo "") exitWith {false};
    private _weaponState = [_weapon] call
        A3VRHybrid_fnc_proxyCurrentWeaponState;
    private _loadout = getUnitLoadout player;
    _loadout set [0, []];
    _loadout set [1, []];
    _loadout set [2, []];
    private _weaponSlot = if (_weapon isEqualTo secondaryWeapon player) then {
        1
    } else {
        if (_weapon isEqualTo handgunWeapon player) then {2} else {0}
    };
    _loadout set [_weaponSlot, _weaponState];
    {
        private _container = _loadout param [_x, []];
        if (_container isEqualType [] && {count _container > 0}) then {
            _container = +_container;
            if (count _container < 2) then {_container pushBack [];};
            _container set [1, []];
            _loadout set [_x, _container];
        };
    } forEach [3, 4, 5];
    _loadout set [6, ""];
    _loadout set [7, ""];
    _loadout set [8, []];
    _loadout set [9, []];
    _rig setUnitLoadout [_loadout, false];

    // Never give the hidden rig spare magazines. Its only job is to mirror
    // the currently loaded magazine; reserves made the engine auto-reload it
    // in the background and produced an unrelated charging/reload sound.
    private _copied = 0;

    [_rig, currentWeapon player, currentWeaponMode player,
        currentMuzzle player] call A3VRHybrid_fnc_proxySelectWeapon;
    // setUnitLoadout can silently fill an empty magazine to capacity on a
    // createAgent. Overwrite it with the authoritative weaponState, including
    // zero, before the rig is ever allowed to fire.
    private _playerState = weaponState player;
    if (count _playerState >= 5 && {
        (_playerState # 0) isEqualTo currentWeapon player} && {
        (_playerState # 1) isEqualTo currentMuzzle player}) then {
        _rig setAmmo [currentMuzzle player, (_playerState # 4) max 0];
    };
    private _rigState = weaponState _rig;
    private _ready = count _rigState >= 4 &&
        {(_rigState # 0) isEqualTo currentWeapon player} &&
        {(_rigState # 1) isEqualTo currentMuzzle player} &&
        {(_rigState # 2) isEqualTo currentWeaponMode player};
    diag_log format [
        "[A3VR] Proxy rig current-only loadout ready=%1 weapon=%2 muzzle=%3 mode=%4 spareMagazines=%5 state=%6",
        _ready,
        currentWeapon player, currentMuzzle player, currentWeaponMode player,
        _copied, _rigState
    ];
    _ready
};

A3VRHybrid_fnc_proxyFireProfile = {
    params ["_state"];
    if (count _state < 3) exitWith {[false, 1, 0.1, ""]};
    private _weapon = _state # 0;
    private _muzzle = _state # 1;
    private _mode = _state # 2;
    private _weaponConfig = configFile >> "CfgWeapons" >> _weapon;
    private _muzzleConfig = _weaponConfig;
    if (_muzzle isNotEqualTo "" && {_muzzle isNotEqualTo _weapon} &&
        {isClass (_weaponConfig >> _muzzle)}) then {
        _muzzleConfig = _weaponConfig >> _muzzle;
    };
    private _modeConfig = _muzzleConfig >> _mode;
    if (!isClass _modeConfig) then {
        _modeConfig = _weaponConfig >> _mode;
    };
    if (!isClass _modeConfig &&
        {_mode in ["this", _weapon, _muzzle]}) then {
        _modeConfig = _muzzleConfig;
    };
    private _automatic = getNumber (_modeConfig >> "autoFire") > 0;
    private _burst = getNumber (_modeConfig >> "burst");
    if (_burst <= 0) then {_burst = 1;};
    private _reloadTime = getNumber (_modeConfig >> "reloadTime");
    if (_reloadTime <= 0) then {_reloadTime = 0.1;};
    [_automatic, _burst, _reloadTime, configName _modeConfig]
};

/* Empty trigger feedback uses the current weapon's own configured drySound.
   Automatic reload remains disabled and no ammunition or animation state is
   changed by this feedback path. */
A3VRHybrid_fnc_proxyDryFire = {
    params ["_weapon", "_muzzle"];
    if (diag_tickTime - A3VRHybrid_proxyLastDryFireAt < 0.12) exitWith {};
    A3VRHybrid_proxyLastDryFireAt = diag_tickTime;
    private _weaponConfig = configFile >> "CfgWeapons" >> _weapon;
    private _muzzleConfig = if (_muzzle isNotEqualTo "" &&
        {_muzzle isNotEqualTo _weapon} &&
        {isClass (_weaponConfig >> _muzzle)}) then {
        _weaponConfig >> _muzzle
    } else {_weaponConfig};
    private _dry = getArray (_muzzleConfig >> "drySound");
    if (_dry isEqualTo []) then {
        _dry = getArray (_weaponConfig >> "drySound");
    };
    if (_dry isEqualTo []) exitWith {
        diag_log format [
            "[A3VR] Proxy dry fire has no configured sound weapon=%1 muzzle=%2",
            _weapon, _muzzle];
    };
    private _file = _dry param [0, ""];
    if ((_file select [0, 1]) isEqualTo "\") then {
        _file = _file select [1];
    };
    if (_file isEqualTo "") exitWith {};
    private _lower = toLower _file;
    private _hasExtension = (count _lower >= 4) && {
        (_lower select [count _lower - 4, 4]) in [".wss", ".ogg", ".wav"]
    };
    if (!_hasExtension) then {
        {
            if (fileExists (_file + _x)) exitWith {_file = _file + _x;};
        } forEach [".wss", ".ogg", ".wav"];
    };
    private _volume = _dry param [1, 1];
    private _pitch = _dry param [2, 1];
    private _distance = _dry param [3, 20];
    playSound3D [_file, objNull, false, +A3VRHybrid_proxyMuzzlePosition,
        _volume, _pitch, _distance, 0, true, false];
    diag_log format [
        "[A3VR] Proxy native dry fire weapon=%1 muzzle=%2 sound=%3",
        _weapon, _muzzle, _file];
};

/* CfgWeapons mixes player-selectable modes with hidden AI modes such as
   AIClose/AIMedium. Cycling into one of those modes starts its configured
   multi-round burst and destroys the per-weapon cadence. */
A3VRHybrid_fnc_proxyPlayerFireModes = {
    params ["_weapon", "_muzzle"];
    private _weaponConfig = configFile >> "CfgWeapons" >> _weapon;
    private _muzzleConfig = if (_muzzle isNotEqualTo "" &&
        {_muzzle isNotEqualTo _weapon} &&
        {isClass (_weaponConfig >> _muzzle)}) then {
        _weaponConfig >> _muzzle
    } else {_weaponConfig};
    private _modes = getArray (_muzzleConfig >> "modes");
    if (_modes isEqualTo []) then {
        _modes = getArray (_weaponConfig >> "modes");
    };
    private _visible = _modes select {
        private _config = _muzzleConfig >> _x;
        if (!isClass _config) then {_config = _weaponConfig >> _x;};
        isClass _config && {getNumber (_config >> "showToPlayer") > 0}
    };
    if (_visible isEqualTo []) then {
        _visible = _modes select {
            private _name = toLower _x;
            (_name find "ai") isNotEqualTo 0 &&
            {!(_name in ["close", "short", "medium", "far"])}
        };
    };
    _visible
};

A3VRHybrid_fnc_proxyWeaponProxyName = {
    params ["_object", "_weapon"];
    private _type = getNumber
        (configFile >> "CfgWeapons" >> _weapon >> "type");
    private _names = [
        "proxy:\a3\characters_f\proxies\pistol.001",
        "proxy:\a3\characters_f\proxies\weapon.001",
        "proxy:\a3\characters_f\proxies\launcher.001",
        "proxy:\a3\characters_f\proxies\binoculars.001"
    ];
    private _index = (([1, 4, 4096] find _type) + 1) max 0;
    private _preferred = _names # (_index min 3);
    private _available = _object selectionNames 1;
    private _matched = _available findIf {
        (toLower _x) isEqualTo (toLower _preferred)
    };
    if (_matched >= 0) exitWith {_available # _matched};

    // Modded skeletons sometimes rename the standard proxy. Prefer a proxy
    // that explicitly represents a held weapon, never a backpack/equipment
    // proxy that happens to contain the word weapon in its model path.
    private _fallback = _available findIf {
        private _name = toLower _x;
        (_name find "proxy:" isEqualTo 0) && {
            (_name find "weapon" >= 0) ||
            {_name find "pistol" >= 0} ||
            {_name find "launcher" >= 0}
        }
    };
    if (_fallback >= 0) then {_available # _fallback} else {""}
};

A3VRHybrid_fnc_proxyFindHolderProxy = {
    params ["_holder"];
    private _result = "";
    {
        private _names = _holder selectionNames _x;
        private _index = _names findIf {
            private _name = toLower _x;
            (_name find "proxy:" isEqualTo 0) &&
            {(_name find "weapon" >= 0) ||
             {_name find "pistol" >= 0} ||
             {_name find "rifle" >= 0} ||
             {_name find "launcher" >= 0}}
        };
        if (_index >= 0) exitWith {_result = _names # _index;};
    } forEach [1, 0, 2];
    _result
};

A3VRHybrid_fnc_proxyFindLinkProxy = {
    params ["_object", "_linkProxy"];
    if (isNull _object || {_linkProxy isEqualTo ""}) exitWith {""};
    private _needle = toLower _linkProxy;
    if ((_needle select [0, 1]) isEqualTo "\") then {
        _needle = _needle select [1];
    };
    private _extension = _needle find ".p3d";
    if (_extension >= 0) then {
        _needle = _needle select [0, _extension];
    };
    private _result = "";
    {
        private _names = _object selectionNames _x;
        private _index = _names findIf {
            private _name = toLower _x;
            (_name find "proxy:" isEqualTo 0) &&
            {(_name find _needle) >= 0}
        };
        if (_index >= 0) exitWith {_result = _names # _index;};
    } forEach [1, 0, 2];
    _result
};

A3VRHybrid_fnc_proxyCollectFlashSelections = {
    params ["_object"];
    private _result = [];
    if (isNull _object) exitWith {_result};
    for "_lod" from 0 to 12 do {
        {
            private _name = toLower _x;
            if ((_name find "zasleh") >= 0 ||
                {(_name find "muzzleflash") >= 0}) then {
                _result pushBackUnique _x;
            };
        } forEach (_object selectionNames _lod);
    };
    {
        _result pushBackUnique _x;
    } forEach [
        "zasleh", "zasleh2", "zasleh3", "zasleh_proxy",
        "muzzleflash", "muzzleflash1", "muzzleflash2", "muzzle_flash"
    ];
    _result
};

A3VRHybrid_fnc_proxyHideMuzzleFlash = {
    params ["_object", ["_hidden", true]];
    if (isNull _object) exitWith {};
    {
        _object hideSelection [_x, _hidden];
    } forEach A3VRHybrid_proxyFlashSelections;
    {
        // A number of weapon P3Ds expose the flash through a model.cfg hide
        // animation rather than a directly hideable selection. Driving both
        // representations keeps raw proxy models dark while idle.
        _object animate [_x, [0, 1] select _hidden, true];
    } forEach A3VRHybrid_proxyFlashAnimations;
};

A3VRHybrid_fnc_proxyPulseMuzzleFlash = {
    if (A3VRHybrid_proxySuppressed ||
        {isNull A3VRHybrid_proxyVisual}) exitWith {};
    A3VRHybrid_proxyFlashGeneration =
        A3VRHybrid_proxyFlashGeneration + 1;
    A3VRHybrid_proxyFlashUntil = diag_tickTime + 0.022;
    [A3VRHybrid_proxyVisual, false] call
        A3VRHybrid_fnc_proxyHideMuzzleFlash;
};

/* Raw P3Ds do not share one universal meaning for reload/ammo/revolving model
   sources. Record state for diagnostics but leave belt, box and magazine
   geometry untouched; forcing generic phases exploded the M60 geometry and
   removed its ammunition box when the counter reached zero. */
A3VRHybrid_fnc_proxyUpdateAmmoVisual = {
    if (isNull A3VRHybrid_proxyVisual || {isNull player}) exitWith {};
    private _state = weaponState player;
    if (count _state < 5) exitWith {};
    private _magazine = _state # 3;
    private _rounds = _state # 4;
    private _capacity = getNumber
        (configFile >> "CfgMagazines" >> _magazine >> "count");
    _capacity = _capacity max 1;
    private _signature = [_magazine, _rounds, _capacity];
    if (_signature isEqualTo A3VRHybrid_proxyAmmoVisualState) exitWith {};
    A3VRHybrid_proxyAmmoVisualState = _signature;

    private _layout = str [currentWeapon player, _magazine,
        animationNames A3VRHybrid_proxyVisual];
    if (_layout isNotEqualTo A3VRHybrid_proxyAmmoVisualLayout) then {
        A3VRHybrid_proxyAmmoVisualLayout = _layout;
        diag_log format [
            "[A3VR] Proxy ammo visual native-only weapon=%1 magazine=%2 rounds=%3 capacity=%4 animations=%5",
            currentWeapon player, _magazine, _rounds,
            _capacity, animationNames A3VRHybrid_proxyVisual
        ];
    };
};

/* Reproduce only the engine-defined CfgModels weapon controllers, with their
   documented ranges. The broken build sent rounds-spent (0..capacity) to the
   revolving controller (which is strictly 1 full .. 0 empty) and also sent
   reload phases into the separate magazine model; that exploded M60 parts and
   rotated M16 magazines. */
A3VRHybrid_fnc_proxyUpdateNativeWeaponSources = {
    if (isNull A3VRHybrid_proxyVisual || {isNull player}) exitWith {};
    private _playerState = weaponState player;
    if (count _playerState < 7) exitWith {};
    private _weapon = _playerState # 0;
    private _muzzle = _playerState # 1;
    private _roundPhase = _playerState # 5;
    if (!isNull A3VRHybrid_proxyRig) then {
        private _rigState = weaponState A3VRHybrid_proxyRig;
        if (count _rigState >= 7 && {
            (_rigState # 0) isEqualTo _weapon} && {
            (_rigState # 1) isEqualTo _muzzle}) then {
            _roundPhase = _rigState # 5;
        };
    };
    _roundPhase = (_roundPhase max 0) min 1;
    private _magazine = _playerState # 3;
    private _rounds = (_playerState # 4) max 0;
    private _capacity = getNumber
        (configFile >> "CfgMagazines" >> _magazine >> "count");
    _capacity = _capacity max 1;

    // weaponState may briefly expose an empty/new magazine while the engine is
    // still reloading. Freezing the last real controller state prevents belt
    // and box proxies from alternating between present and absent mid-reload.
    if (A3VRHybrid_proxyReloadActive &&
        {(A3VRHybrid_proxyModelAmmoState # 0) isNotEqualTo ""}) then {
        _magazine = A3VRHybrid_proxyModelAmmoState # 0;
        _rounds = A3VRHybrid_proxyModelAmmoState # 1;
        _capacity = A3VRHybrid_proxyModelAmmoState # 2;
        _roundPhase = 0;
    } else {
        if (_magazine isNotEqualTo "") then {
            A3VRHybrid_proxyModelAmmoState = [
                _magazine, _rounds, _capacity];
        };
    };

    // The engine decrements ammo immediately and then moves reload from 1 to
    // 0. Adding that phase back produces the documented smooth transition for
    // revolving while ammo itself remains the exact discrete round count.
    private _revolving = ((_rounds + _roundPhase) / _capacity) max 0 min 1;
    private _magazineReload = A3VRHybrid_proxyReloadPhase;
    private _empty = [0, 1] select (_rounds <= 0);
    private _muzzles = getArray
        (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
    private _muzzleIndex = 0;
    if (_muzzle isNotEqualTo _weapon) then {
        _muzzleIndex = _muzzles find _muzzle;
        if (_muzzleIndex < 0) then {_muzzleIndex = 0;};
    };
    private _suffix = "." + str _muzzleIndex;
    {
        _x params ["_source", "_phase"];
        A3VRHybrid_proxyVisual animateSource [_source, _phase, true];
        A3VRHybrid_proxyVisual animateSource [
            _source + _suffix, _phase, true];
    } forEach [
        ["reload", _roundPhase],
        ["reloadMagazine", _magazineReload],
        ["revolving", _revolving],
        ["ammo", _rounds],
        ["isEmpty", _empty],
        ["isEmptyNoReload", _empty]
    ];

    // hasMagazine remains engine-owned. Forcing it on a raw P3D hid pistol
    // magazines and M60 boxes; isEmpty only drives the weapon's configured
    // empty-bolt/slide state and does not invent magazine visibility.
    // A few DLC raw P3Ds instead expose the loaded container through a direct
    // has-magazine animation. Keep it present for an inserted (even empty)
    // magazine and hide it only when weaponState reports no magazine at all.
    private _hasMagazine = _magazine isNotEqualTo "";
    {
        private _lower = toLower _x;
        if ((_lower find "unloaded_magazine_hide") >= 0 ||
            {(_lower find "magazine_hasmag_hide") >= 0}) then {
            A3VRHybrid_proxyVisual animate [
                _x, [1, 0] select _hasMagazine, true];
        };
    } forEach (animationNames A3VRHybrid_proxyVisual);

    // Dynamic magazine P3Ds use revolving/ammo for visible rounds. They must
    // never receive reload/reloadMagazine: those phases rotate their complete
    // geometry independently from the weapon proxy.
    {
        private _object = _x param [0, objNull];
        if (!isNull _object && {
            (_x param [5, ""]) isEqualTo "magazine"} && {
            (_x param [8, "proxy"]) isEqualTo "proxy"}) then {
            _object animateSource ["revolving", _revolving, true];
            _object animateSource ["ammo", _rounds, true];
        };
    } forEach A3VRHybrid_proxyAttachments;

    // Belt-fed DLC weapons commonly expose one hide animation per visible
    // round but their raw P3D does not receive the equipped-weapon ammo source.
    // Drive only those explicit bullet selections. The modulo represents the
    // next section of belt entering the feed tray and avoids a two-frame wiggle.
    private _beltLayout = str [
        _weapon, animationNames A3VRHybrid_proxyVisual];
    if (_beltLayout isNotEqualTo A3VRHybrid_proxyBeltAnimationLog) then {
        A3VRHybrid_proxyBeltAnimationLog = _beltLayout;
        A3VRHybrid_proxyBeltAnimations = [];
        {
            private _lower = toLower _x;
            if ((_lower find "bullet") >= 0 &&
                {(_lower find "shake") < 0} &&
                {(_lower find "empty") < 0} &&
                {(_lower find "reload") < 0} &&
                {(_lower find "_rm") < 0} &&
                {(_lower find "unhide") < 0} &&
                {(_lower find "elevate") < 0} &&
                {(_lower find "move") < 0}) then {
                A3VRHybrid_proxyBeltAnimations pushBack _x;
            };
        } forEach (animationNames A3VRHybrid_proxyVisual);
        if (count A3VRHybrid_proxyBeltAnimations > 1) then {
            diag_log format [
                "[A3VR] Proxy belt feed weapon=%1 animations=%2",
                _weapon, A3VRHybrid_proxyBeltAnimations];
        };
    };
    private _beltCount = count A3VRHybrid_proxyBeltAnimations;
    if (_beltCount > 1) then {
        private _visibleBeltRounds = if (_rounds <= 0) then {0} else {
            ((_rounds - 1) mod _beltCount) + 1
        };
        A3VRHybrid_proxyBeltFeedPhase =
            1 - (_visibleBeltRounds / _beltCount);
        {
            A3VRHybrid_proxyVisual animate [
                _x, [0, 1] select (_forEachIndex >= _visibleBeltRounds),
                true];
        } forEach A3VRHybrid_proxyBeltAnimations;
    };
};

/* Advance whatever feed/operating animations the current model exposes. A
   non-repeating fractional phase avoids the rigid two-frame toggle while
   remaining weapon- and DLC-agnostic. */
A3VRHybrid_fnc_proxyPulseBeltFeed = {
};

/* Mirror the configured cartridge at the visible weapon's real ejection memory
   point. The hidden firing rig still creates the engine cartridge at its parked
   weapon behind the HMD, so remove that local visual and leave exactly one
   casing origin on the controller-aligned weapon. */
A3VRHybrid_fnc_proxyEjectCasing = {
    params ["_ammo", ["_weapon", ""], ["_muzzle", ""]];
    private _cartridge = getText
        (configFile >> "CfgAmmo" >> _ammo >> "cartridge");
    if (_cartridge isEqualTo "" ||
        {!isClass (configFile >> "CfgVehicles" >> _cartridge)}) exitWith {};

    private _forward = vectorNormalized A3VRHybrid_proxyMuzzleDirection;
    private _up = vectorNormalized A3VRHybrid_proxyMuzzleUp;
    private _right = vectorNormalized (_forward vectorCrossProduct _up);
    private _position = +A3VRHybrid_proxyMuzzlePosition;
    private _ejectDirection = +_right;
    private _memoryName = "fallback";
    // Composite holders retain the hidden raw P3D helper. Raw-model fallback
    // promotes that same helper to proxyVisual and clears proxyGeometry, so
    // both paths must expose a model-space source for cartridge memory points.
    private _modelSource = if (!isNull A3VRHybrid_proxyGeometry) then {
        A3VRHybrid_proxyGeometry
    } else {
        if (!A3VRHybrid_proxyVisualComposite &&
            {!isNull A3VRHybrid_proxyVisual}) then {
            A3VRHybrid_proxyVisual
        } else {objNull}
    };
    if (!isNull _modelSource) then {
        /* Read memory points from the original weapon P3D. selectionPosition
           on WeaponHolderSimulated returns the holder/proxy coordinate space,
           which is not the weapon model space for every DLC. Map the raw P3D
           point from its muzzle basis directly onto the visible VR muzzle. */
        private _modelForward = vectorNormalized
            A3VRHybrid_proxyModelForward;
        private _modelUp = vectorNormalized A3VRHybrid_proxyModelUp;
        private _modelRight = vectorNormalized
            (_modelForward vectorCrossProduct _modelUp);
        _modelUp = vectorNormalized
            (_modelRight vectorCrossProduct _modelForward);
        private _modelVectorToWorld = {
            params ["_modelVector"];
            (_right vectorMultiply
                (_modelVector vectorDotProduct _modelRight)) vectorAdd
            (_forward vectorMultiply
                (_modelVector vectorDotProduct _modelForward)) vectorAdd
            (_up vectorMultiply
                (_modelVector vectorDotProduct _modelUp))
        };
        private _modelPointToWorld = {
            params ["_modelPoint"];
            A3VRHybrid_proxyBaseMuzzlePosition vectorAdd
                ([_modelPoint vectorDiff A3VRHybrid_proxyModelMuzzle] call
                    _modelVectorToWorld)
        };

        private _bounds = boundingBoxReal _modelSource;
        private _minimum = _bounds param [0, [-0.1, -0.1, -0.1]];
        private _maximum = _bounds param [1, [0.1, 0.1, 0.1]];
        private _forwardMin = 1000000;
        private _forwardMax = -1000000;
        private _rightMin = 1000000;
        private _rightMax = -1000000;
        private _upMin = 1000000;
        private _upMax = -1000000;
        {
            private _cornerX = _x;
            {
                private _cornerY = _x;
                {
                    private _corner = [_cornerX, _cornerY, _x];
                    private _cornerForward =
                        _corner vectorDotProduct _modelForward;
                    private _cornerRight =
                        _corner vectorDotProduct _modelRight;
                    private _cornerUp = _corner vectorDotProduct _modelUp;
                    _forwardMin = _forwardMin min _cornerForward;
                    _forwardMax = _forwardMax max _cornerForward;
                    _rightMin = _rightMin min _cornerRight;
                    _rightMax = _rightMax max _cornerRight;
                    _upMin = _upMin min _cornerUp;
                    _upMax = _upMax max _cornerUp;
                } forEach [_minimum # 2, _maximum # 2];
            } forEach [_minimum # 1, _maximum # 1];
        } forEach [_minimum # 0, _maximum # 0];

        // Prefer the memory-point names declared by the active weapon/muzzle.
        private _weaponConfig = configFile >> "CfgWeapons" >> _weapon;
        private _muzzleConfig = _weaponConfig;
        if (_muzzle isNotEqualTo "" &&
            {_muzzle isNotEqualTo _weapon} &&
            {isClass (_weaponConfig >> _muzzle)}) then {
            _muzzleConfig = _weaponConfig >> _muzzle;
        };
        private _startNames = [];
        private _endNames = [];
        {
            private _configuredStart = getText (_x >> "cartridgePos");
            private _configuredEnd = getText (_x >> "cartridgeVel");
            if (_configuredStart isNotEqualTo "") then {
                _startNames pushBackUnique _configuredStart;
            };
            if (_configuredEnd isNotEqualTo "") then {
                _endNames pushBackUnique _configuredEnd;
            };
        } forEach [_muzzleConfig, _weaponConfig];
        {
            _startNames pushBackUnique _x;
        } forEach [
            "nabojnicestart", "nabojnice start", "ejectstart",
            "eject start", "cartridge_start", "cartridge start"
        ];
        {
            _endNames pushBackUnique _x;
        } forEach [
            "nabojniceend", "nabojnice end", "ejectend",
            "eject end", "cartridge_end", "cartridge end"
        ];

        private _modelSpan = ((_forwardMax - _forwardMin) max 0.08);
        private _sideSpan = ((_rightMax - _rightMin) max 0.03);
        private _heightSpan = ((_upMax - _upMin) max 0.03);
        private _tolerance = ((_modelSpan * 0.08) max 0.025);
        private _muzzleForward = A3VRHybrid_proxyModelMuzzle
            vectorDotProduct _modelForward;
        private _start = [];
        private _end = [];
        {
            private _candidate = _modelSource selectionPosition
                [_x, "Memory"];
            private _candidateForward =
                _candidate vectorDotProduct _modelForward;
            private _candidateRight =
                _candidate vectorDotProduct _modelRight;
            private _candidateUp = _candidate vectorDotProduct _modelUp;
            private _insideModel = vectorMagnitude _candidate > 0.01 &&
                {_candidateForward >= (_forwardMin - _tolerance)} &&
                {_candidateForward <= (_forwardMax + _tolerance)} &&
                {_candidateForward <=
                    (_muzzleForward + ((_modelSpan * 0.08) max 0.02))} &&
                {_candidateRight >= (_rightMin - _tolerance)} &&
                {_candidateRight <= (_rightMax + _tolerance)} &&
                {_candidateUp >= (_upMin - _tolerance)} &&
                {_candidateUp <= (_upMax + _tolerance)};
            if (_insideModel) exitWith {
                _start = _candidate;
                _memoryName = _x;
            };
        } forEach _startNames;
        {
            private _candidate = _modelSource selectionPosition
                [_x, "Memory"];
            if (vectorMagnitude _candidate > 0.01) exitWith {_end = _candidate;};
        } forEach _endNames;
        if (count _start >= 3) then {
            _position = [_start] call _modelPointToWorld;
            if (count _end >= 3) then {
                private _worldDirection = [
                    _end vectorDiff _start
                ] call _modelVectorToWorld;
                if (vectorMagnitude _worldDirection > 0.005) then {
                    _ejectDirection = vectorNormalized _worldDirection;
                };
            };
        } else {
            /* Some DLC models (including tested M60 variants) do not expose a
               cartridge memory point. Derive a receiver-side point from the
               P3D's oriented bounds, with no rifle-sized absolute offset. */
            private _rearSpan = ((_muzzleForward - _forwardMin) max 0.08);
            private _receiverForward = _muzzleForward - (_rearSpan * 0.48);
            private _receiverRight = _rightMax - (_sideSpan * 0.12);
            private _receiverUp = ((_upMin + _upMax) * 0.5) +
                (_heightSpan * 0.12);
            private _fallbackPoint =
                (_modelForward vectorMultiply _receiverForward) vectorAdd
                (_modelRight vectorMultiply _receiverRight) vectorAdd
                (_modelUp vectorMultiply _receiverUp);
            _position = [_fallbackPoint] call _modelPointToWorld;
            _memoryName = format ["bounds-fallback-%1m", _rearSpan * 0.48];
        };
    };
    private _ejectLog = str [currentWeapon player, _memoryName];
    if (_ejectLog isNotEqualTo A3VRHybrid_proxyEjectMemoryLog) then {
        A3VRHybrid_proxyEjectMemoryLog = _ejectLog;
        diag_log format [
            "[A3VR] Proxy casing origin weapon=%1 memory=%2 muzzleDistance=%3 cartridge=%4",
            currentWeapon player, _memoryName,
            vectorMagnitude
                (_position vectorDiff A3VRHybrid_proxyBaseMuzzlePosition),
            _cartridge
        ];
    };

    // FiredMan is raised by the hidden rig after Arma has accepted the shot.
    // Its native cartridge is a local CfgVehicles object emitted around the
    // parked rig, several metres behind the visible weapon. Remove it over a
    // few frames (creation timing varies by weapon/DLC) without touching the
    // proxy casings tracked below.
    if (!isNull A3VRHybrid_proxyRig) then {
        private _rigPosition = getPosWorld A3VRHybrid_proxyRig;
        private _trackedCasings = A3VRHybrid_proxyCasings apply {
            _x param [0, objNull]
        };
        [_cartridge, _rigPosition, _trackedCasings] spawn {
            params ["_nativeClass", "_nativeOrigin", "_preserve"];
            for "_pass" from 0 to 2 do {
                if (_pass > 0) then {uiSleep 0.01;};
                {
                    if (!isNull _x && {!(_x in _preserve)}) then {
                        deleteVehicle _x;
                    };
                } forEach nearestObjects [
                    ASLToAGL _nativeOrigin, [_nativeClass], 2.25, true
                ];
            };
        };
    };

    private _object = createVehicleLocal [
        _cartridge, ASLToAGL _position, [], 0, "CAN_COLLIDE"];
    if (isNull _object) exitWith {};
    _object setPosWorld _position;
    _object setVectorDirAndUp [_ejectDirection, _up];
    _object disableCollisionWith player;
    if (!isNull A3VRHybrid_proxyVisual) then {
        _object disableCollisionWith A3VRHybrid_proxyVisual;
    };
    if (!isNull A3VRHybrid_proxyGeometry) then {
        _object disableCollisionWith A3VRHybrid_proxyGeometry;
    };
    {
        private _attachment = _x param [0, objNull];
        if (!isNull _attachment) then {
            _object disableCollisionWith _attachment;
        };
    } forEach A3VRHybrid_proxyAttachments;
    private _ejectVelocity =
        (_ejectDirection vectorMultiply random [1.8, 2.5, 3.2]) vectorAdd
        (_up vectorMultiply random [0.45, 0.85, 1.35]) vectorAdd
        (_forward vectorMultiply random [-0.45, -0.18, 0.08]) vectorAdd
        velocity player;
    // Keep the creation frame fixed at the port so the first rendered sample
    // cannot already appear several centimetres away from a moving VR weapon.
    _object setVelocity (velocity player);
    [_object, _ejectVelocity] spawn {
        params ["_casing", "_velocity"];
        uiSleep 0.001;
        if (!isNull _casing) then {_casing setVelocity _velocity;};
    };
    _object setAngularVelocity [
        random [-18, 0, 18], random [-22, 0, 22], random [-16, 0, 16]];
    A3VRHybrid_proxyCasings pushBack [_object, diag_tickTime + 6];
    if (count A3VRHybrid_proxyCasings > 48) then {
        private _old = A3VRHybrid_proxyCasings deleteAt 0;
        deleteVehicle (_old param [0, objNull]);
    };
};

A3VRHybrid_fnc_proxyCleanupCasings = {
    private _kept = [];
    {
        _x params ["_object", "_expires"];
        if (isNull _object || {diag_tickTime >= _expires}) then {
            if (!isNull _object) then {deleteVehicle _object;};
        } else {_kept pushBack _x;};
    } forEach A3VRHybrid_proxyCasings;
    A3VRHybrid_proxyCasings = _kept;
};

A3VRHybrid_fnc_proxyCreateAttachments = {
    params ["_weapon", "_state", "_weaponObject", "_position"];
    A3VRHybrid_proxyAttachments = [];
    if (isNull _weaponObject) exitWith {};
    private _slotsRoot = configFile >> "CfgWeapons" >> _weapon >>
        "WeaponSlotsInfo";
    private _slotConfigs = if (isClass _slotsRoot) then {
        configProperties [_slotsRoot, "isClass _x", true]
    } else {[]};
    private _requested = [
        [_state param [1, ""], "muzzle"],
        [_state param [2, ""], "pointer"],
        [_state param [3, ""], "cows"],
        [_state param [6, ""], "underbarrel"]
    ];
    {
        _x params ["_attachment", "_hint"];
        if (_attachment isNotEqualTo "") then {
            private _slotIndex = _slotConfigs findIf {
                _attachment in (compatibleItems [
                    _weapon, configName _x])
            };
            if (_slotIndex < 0) then {
                _slotIndex = _slotConfigs findIf {
                    private _name = toLower (configName _x);
                    (_name find _hint) >= 0 ||
                    {_hint isEqualTo "cows" &&
                     {(_name find "optic") >= 0}}
                };
            };
            private _slot = if (_slotIndex >= 0) then {
                _slotConfigs # _slotIndex
            } else {configNull};
            private _linkProxy = if (isNull _slot) then {""} else {
                getText (_slot >> "linkProxy")
            };
            private _selection = [
                _weaponObject, _linkProxy
            ] call A3VRHybrid_fnc_proxyFindLinkProxy;
            private _itemConfig = configFile >> "CfgWeapons" >>
                _attachment;
            private _model = getText (_itemConfig >> "model");
            if (_model isNotEqualTo "" &&
                {(_model select [0, 1]) isEqualTo "\"}) then {
                _model = _model select [1];
            };
            if (_selection isNotEqualTo "" &&
                {_model isNotEqualTo ""}) then {
                private _vectors = _weaponObject
                    selectionVectorDirAndUp [_selection, 1];
                private _origin = selectionPosition [
                    _weaponObject, _selection, 0];
                if (count _vectors >= 2) then {
                    private _object = createSimpleObject [
                        _model, _position, true];
                    if (!isNull _object) then {
                        [_object, _itemConfig, _attachment] call
                            A3VRHybrid_fnc_proxyApplyConfigAppearance;
                        A3VRHybrid_proxyAttachments pushBack [
                            _object, _origin,
                            vectorNormalized (_vectors # 0),
                            vectorNormalized (_vectors # 1),
                            _attachment, configName _slot, _selection, _hint
                        ];
                    };
                };
            } else {
                diag_log format [
                    "[A3VR] Proxy attachment mount unavailable item=%1 slot=%2 link=%3 selection=%4 model=%5",
                    _attachment,
                    if (isNull _slot) then {""} else {configName _slot},
                    _linkProxy, _selection, _model
                ];
            };
        };
    } forEach _requested;
};

A3VRHybrid_fnc_proxyCreateMagazine = {
    params ["_state", "_weaponObject", "_position"];
    if (isNull _weaponObject) exitWith {};
    private _magazineState = _state param [4, []];
    if (!(_magazineState isEqualType []) ||
        {count _magazineState < 1}) exitWith {};
    private _magazineClass = _magazineState # 0;
    if (_magazineClass isEqualTo "") exitWith {};
    private _magazineConfig = configFile >> "CfgMagazines" >> _magazineClass;
    // model is commonly mag_univ.p3d: an inventory placeholder, not the
    // weapon-specific inserted magazine. modelSpecial is the procedural P3D
    // intended for the weapon's magazine proxy and must take precedence.
    private _special = getNumber
        (_magazineConfig >> "modelSpecialIsProxy") > 0;
    private _model = if (_special) then {
        getText (_magazineConfig >> "modelSpecial")
    } else {""};
    if (_model isEqualTo "") then {
        _model = getText (_magazineConfig >> "model");
    };
    if (_model isEqualTo "") exitWith {
        diag_log format [
            "[A3VR] Proxy magazine has no model class=%1", _magazineClass];
    };
    if ((_model select [0, 1]) isEqualTo "\") then {
        _model = _model select [1];
    };
    if ((toLower _model) find "mag_univ.p3d" >= 0) exitWith {
        diag_log format [
            "[A3VR] Proxy magazine skipped generic inventory model class=%1 model=%2",
            _magazineClass, _model
        ];
    };

    private _selection = [
        _weaponObject, _model
    ] call A3VRHybrid_fnc_proxyFindLinkProxy;
    if (_selection isEqualTo "") then {
        {
            private _names = _weaponObject selectionNames _x;
            private _index = _names findIf {
                private _name = toLower _x;
                (_name find "proxy:" isEqualTo 0) && {
                    (_name find "magazine" >= 0) ||
                    {(_name find "mag_" >= 0)} ||
                    {(_name find "magazineproxies" >= 0)}
                }
            };
            if (_index >= 0) exitWith {_selection = _names # _index;};
        } forEach [1, 0, 2];
    };
    if (_selection isEqualTo "") exitWith {
        diag_log format [
            "[A3VR] Proxy magazine mount unavailable class=%1 model=%2",
            _magazineClass, _model
        ];
    };

    private _vectors = _weaponObject selectionVectorDirAndUp [_selection, 1];
    if (count _vectors < 2) exitWith {
        diag_log format [
            "[A3VR] Proxy magazine mount has no basis class=%1 selection=%2",
            _magazineClass, _selection
        ];
    };
    private _origin = selectionPosition [_weaponObject, _selection, 0];
    private _object = createSimpleObject [_model, _position, true];
    if (isNull _object) exitWith {
        diag_log format [
            "[A3VR] Proxy magazine model failed class=%1 model=%2",
            _magazineClass, _model
        ];
    };
    [_object, _magazineConfig, _magazineClass] call
        A3VRHybrid_fnc_proxyApplyConfigAppearance;
    // Hide the source geometry only after the replacement exists. Failed
    // mounts previously removed a valid integral magazine with no fallback.
    _weaponObject hideSelection [_selection, true];
    A3VRHybrid_proxyAttachments pushBack [
        _object, _origin, vectorNormalized (_vectors # 0),
        vectorNormalized (_vectors # 1), _magazineClass,
        "magazine", _selection, "magazine", "proxy"
    ];
    diag_log format [
        "[A3VR] Proxy magazine visual class=%1 rounds=%2 selection=%3 model=%4 special=%5 mount=%6",
        _magazineClass, _magazineState param [1, 0], _selection, _model,
        _special, "proxy"
    ];
};

A3VRHybrid_fnc_proxyPlaceAttachments = {
    params ["_visualPosition", "_visualForward", "_visualUp"];
    {
        _x params ["_object", "_origin", "_localForward", "_localUp",
            "_itemClass", "_slotName", "_selection", ["_role", ""],
            ["_mountKind", "proxy"]];
        if (!isNull _object) then {
            if (_slotName isEqualTo "magazine" &&
                {_mountKind isEqualTo "proxy"} &&
                {_selection isNotEqualTo ""} &&
                {!isNull A3VRHybrid_proxyVisual}) then {
                private _animatedVectors = A3VRHybrid_proxyVisual
                    selectionVectorDirAndUp [_selection, 1];
                private _animatedOrigin = selectionPosition [
                    A3VRHybrid_proxyVisual, _selection, 0];
                if (count _animatedVectors >= 2 &&
                    {vectorMagnitude (_animatedVectors # 0) > 0.5} &&
                    {vectorMagnitude (_animatedVectors # 1) > 0.5} &&
                    {abs ((vectorNormalized (_animatedVectors # 0))
                        vectorDotProduct
                        (vectorNormalized (_animatedVectors # 1))) < 0.98} &&
                    {vectorMagnitude (_animatedOrigin vectorDiff _origin) < 1.25})
                then {
                    _origin = _animatedOrigin;
                    _x set [1, _origin];
                    _localForward = vectorNormalized (_animatedVectors # 0);
                    _localUp = vectorNormalized (_animatedVectors # 1);
                    _x set [2, _localForward];
                    _x set [3, _localUp];
                };
            };
            // Attachment axes are relative to their parent after attachTo.
            // Reattaching at the animated proxy each frame removes the
            // one-frame/world-space drift that left magazines sideways when
            // the controller changed pitch or roll.
            _object attachTo [A3VRHybrid_proxyVisual, _origin];
            _object setVectorDirAndUp [_localForward, _localUp];
        };
    } forEach A3VRHybrid_proxyAttachments;
};

/* Resolve the actual visible end of a muzzle attachment. CfgWeapons muzzlePos
   normally stops at the base weapon's barrel, so a long suppressor can extend
   beyond the projectile origin. Use the configured slot role and the attached
   model's own bounds rather than weapon- or DLC-specific class names. */
A3VRHybrid_fnc_proxyResolveBallisticMuzzle = {
    params ["_baseMuzzle", "_forward"];
    _forward = vectorNormalized _forward;
    private _furthest = 0;
    private _muzzleItems = [];
    {
        private _object = _x param [0, objNull];
        private _role = toLower (_x param [7, ""]);
        if (!isNull _object && {_role isEqualTo "muzzle"}) then {
            _muzzleItems pushBack (_x param [4, ""]);
            private _bounds = boundingBoxReal _object;
            if (count _bounds >= 2) then {
                private _minimum = _bounds # 0;
                private _maximum = _bounds # 1;
                {
                    private _xEdge = _x;
                    {
                        private _yEdge = _x;
                        {
                            private _world = _object modelToWorldVisualWorld
                                [_xEdge, _yEdge, _x];
                            private _projection =
                                (_world vectorDiff _baseMuzzle)
                                vectorDotProduct _forward;
                            _furthest = _furthest max _projection;
                        } forEach [_minimum # 2, _maximum # 2];
                    } forEach [_minimum # 1, _maximum # 1];
                } forEach [_minimum # 0, _maximum # 0];
            };
        };
    } forEach A3VRHybrid_proxyAttachments;
    // The small clearance also keeps the projectile volume outside the base
    // muzzle face. Clamp malformed third-party model bounds to a sane length.
    private _clearance = ((_furthest max 0) min 1.5) + 0.035;
    private _signature = str [currentWeapon player, _muzzleItems,
        round (_clearance * 1000)];
    if (_signature isNotEqualTo A3VRHybrid_proxyMuzzleClearanceLog) then {
        A3VRHybrid_proxyMuzzleClearanceLog = _signature;
        diag_log format [
            "[A3VR] Proxy ballistic muzzle weapon=%1 items=%2 clearance=%3",
            currentWeapon player, _muzzleItems, _clearance
        ];
    };
    _baseMuzzle vectorAdd (_forward vectorMultiply _clearance)
};

A3VRHybrid_fnc_proxyUpdateBipodVisual = {
    private _phase = if (isWeaponDeployed player) then {1} else {0};
    if (!isNull A3VRHybrid_proxyVisual) then {
        A3VRHybrid_proxyVisual animateSource ["bipod", _phase, true];
        A3VRHybrid_proxyVisual animateSource ["bipod_legs", _phase, true];
    };
    {
        private _object = _x param [0, objNull];
        private _slot = toLower (_x param [5, ""]);
        if (!isNull _object &&
            {(_slot find "under") >= 0 || {(_slot find "bipod") >= 0}}) then {
            _object animateSource ["bipod", _phase, true];
            _object animateSource ["bipod_legs", _phase, true];
        };
    } forEach A3VRHybrid_proxyAttachments;
};

A3VRHybrid_fnc_proxyToggleAccessory = {
    params ["_pointerClass"];
    if (_pointerClass isEqualTo "") exitWith {
        A3VRHybrid_proxyAccessoryEnabled = false;
        A3VRHybrid_proxyAccessoryClass = "";
        systemChat "A3VR: current weapon has no laser or flashlight.";
    };
    A3VRHybrid_proxyAccessoryEnabled =
        !A3VRHybrid_proxyAccessoryEnabled ||
        {A3VRHybrid_proxyAccessoryClass isNotEqualTo _pointerClass};
    A3VRHybrid_proxyAccessoryClass = _pointerClass;
    private _config = configFile >> "CfgWeapons" >> _pointerClass;
    private _isFlashlight =
        (toLower _pointerClass find "flashlight") >= 0 ||
        {isClass (_config >> "ItemInfo" >> "FlashLight")};
    private _action = if (_isFlashlight) then {
        ["GunLightOff", "GunLightOn"] select
            A3VRHybrid_proxyAccessoryEnabled
    } else {
        ["IRLaserOff", "IRLaserOn"] select
            A3VRHybrid_proxyAccessoryEnabled
    };
    player action [_action, player];
    if (!isNull A3VRHybrid_proxyRig) then {
        A3VRHybrid_proxyRig action [_action, A3VRHybrid_proxyRig];
    };
    systemChat format ["A3VR %1: %2", _pointerClass,
        ["OFF", "ON"] select A3VRHybrid_proxyAccessoryEnabled];
};

A3VRHybrid_fnc_proxyResolveMount = {
    params ["_object", "_selection", "_modelForward", "_modelUp",
        "_modelMuzzle"];
    if (isNull _object || {_selection isEqualTo ""}) exitWith {[]};
    private _vectors = _object selectionVectorDirAndUp [_selection, 1];
    if (count _vectors < 2) exitWith {[]};
    private _proxyForward = vectorNormalized (_vectors # 0);
    private _proxyUp = vectorNormalized (_vectors # 1);
    private _proxyRight = vectorNormalized
        (_proxyForward vectorCrossProduct _proxyUp);
    _proxyUp = vectorNormalized
        (_proxyRight vectorCrossProduct _proxyForward);
    if (vectorMagnitude _proxyForward < 0.5 ||
        {vectorMagnitude _proxyUp < 0.5}) exitWith {[]};

    private _origin = selectionPosition [_object, _selection, 0];
    private _transform = {
        params ["_vector"];
        [_proxyRight, _proxyForward, _proxyUp, _vector] call
            A3VRHybrid_fnc_proxyTransformVector
    };
    private _localForward = vectorNormalized ([_modelForward] call _transform);
    private _localUp = vectorNormalized ([_modelUp] call _transform);
    private _localRight = vectorNormalized
        (_localForward vectorCrossProduct _localUp);
    _localUp = vectorNormalized (_localRight vectorCrossProduct _localForward);
    private _localMuzzle = _origin vectorAdd ([_modelMuzzle] call _transform);
    [_origin, _localForward, _localUp, _localMuzzle, _selection]
};

A3VRHybrid_fnc_proxySolveObjectBasis = {
    params ["_localForward", "_localUp", "_worldForward", "_worldUp"];
    private _localRight = vectorNormalized
        (_localForward vectorCrossProduct _localUp);
    _localUp = vectorNormalized (_localRight vectorCrossProduct _localForward);
    private _worldRight = vectorNormalized
        (_worldForward vectorCrossProduct _worldUp);
    _worldUp = vectorNormalized (_worldRight vectorCrossProduct _worldForward);

    // R = desiredWeaponBasis * transpose(localWeaponBasis). The returned
    // vectors are the object's local +Y and +Z axes in world space.
    private _objectForward =
        (_worldRight vectorMultiply (_localRight # 1)) vectorAdd
        (_worldForward vectorMultiply (_localForward # 1)) vectorAdd
        (_worldUp vectorMultiply (_localUp # 1));
    private _objectUp =
        (_worldRight vectorMultiply (_localRight # 2)) vectorAdd
        (_worldForward vectorMultiply (_localForward # 2)) vectorAdd
        (_worldUp vectorMultiply (_localUp # 2));
    [vectorNormalized _objectForward, vectorNormalized _objectUp]
};

A3VRHybrid_fnc_proxyPlaceObject = {
    params ["_object", "_mount", "_targetOrigin", "_targetForward",
        "_targetUp"];
    if (isNull _object || {count _mount < 4}) exitWith {[]};
    private _basis = [
        _mount # 1, _mount # 2, _targetForward, _targetUp
    ] call A3VRHybrid_fnc_proxySolveObjectBasis;
    _basis params ["_objectForward", "_objectUp"];
    private _objectRight = vectorNormalized
        (_objectForward vectorCrossProduct _objectUp);
    _objectUp = vectorNormalized
        (_objectRight vectorCrossProduct _objectForward);
    private _originOffset = [
        _objectRight, _objectForward, _objectUp, _mount # 0
    ] call A3VRHybrid_fnc_proxyTransformVector;
    private _objectPosition = _targetOrigin vectorDiff _originOffset;
    _object setVectorDirAndUp [_objectForward, _objectUp];
    _object setPosWorld _objectPosition;
    private _muzzleOffset = [
        _objectRight, _objectForward, _objectUp, _mount # 3
    ] call A3VRHybrid_fnc_proxyTransformVector;
    [_objectPosition vectorAdd _muzzleOffset, _objectForward, _objectUp]
};

/* A Man must remain a free simulation object or its weapon firing controller
   stops advancing after the first shot. Translate its current weapon-proxy
   muzzle onto the visual muzzle; FiredMan later relocates the native effect
   emitters themselves to supply the controller pitch and roll. */
A3VRHybrid_fnc_proxyAlignRigMuzzle = {
    params ["_weaponOrigin", "_weaponForward", "_weaponUp"];
    if (isNull A3VRHybrid_proxyRig ||
        {count A3VRHybrid_proxyRigMount < 4}) exitWith {false};
    [A3VRHybrid_proxyRig, A3VRHybrid_proxyRigMount,
        _weaponOrigin, _weaponForward, _weaponUp] call
        A3VRHybrid_fnc_proxyPlaceObject;
    private _rigForward = vectorNormalized (vectorDir A3VRHybrid_proxyRig);
    private _rigUp = vectorNormalized (vectorUp A3VRHybrid_proxyRig);
    private _rigRight = vectorNormalized
        (_rigForward vectorCrossProduct _rigUp);
    _rigUp = vectorNormalized (_rigRight vectorCrossProduct _rigForward);
    private _actualMuzzle = getPosWorld A3VRHybrid_proxyRig vectorAdd ([
        _rigRight, _rigForward, _rigUp, A3VRHybrid_proxyRigMount # 3
    ] call A3VRHybrid_fnc_proxyTransformVector);
    private _correction = A3VRHybrid_proxyMuzzlePosition vectorDiff
        _actualMuzzle;
    A3VRHybrid_proxyRig setPosWorld
        (getPosWorld A3VRHybrid_proxyRig vectorAdd _correction);
    A3VRHybrid_proxyRig setVelocity [0, 0, 0];
    true
};

A3VRHybrid_fnc_proxyDeleteVisual = {
    A3VRHybrid_proxyFlashGeneration =
        A3VRHybrid_proxyFlashGeneration + 1;
    A3VRHybrid_proxyFlashUntil = -10;
    {
        private _object = _x param [0, objNull];
        if (!isNull _object) then {deleteVehicle _object;};
    } forEach A3VRHybrid_proxyAttachments;
    A3VRHybrid_proxyAttachments = [];
    if (!isNull A3VRHybrid_proxyVisual) then {
        deleteVehicle A3VRHybrid_proxyVisual;
    };
    if (!isNull A3VRHybrid_proxyGeometry) then {
        deleteVehicle A3VRHybrid_proxyGeometry;
    };
    A3VRHybrid_proxyVisual = objNull;
    A3VRHybrid_proxyGeometry = objNull;
    A3VRHybrid_proxyVisualComposite = false;
    A3VRHybrid_proxyVisualSignature = "";
    A3VRHybrid_proxyVisualMount = [];
    A3VRHybrid_proxyFlashSelections = [];
    A3VRHybrid_proxyFlashAnimations = [];
    A3VRHybrid_proxyMuzzleClearanceLog = "";
    A3VRHybrid_proxyAmmoVisualState = [];
    A3VRHybrid_proxyAmmoVisualLayout = "";
    A3VRHybrid_proxyModelAmmoState = ["", 0, 1];
    A3VRHybrid_proxyEjectMemoryLog = "";
    A3VRHybrid_proxyBeltFeedPhase = 0;
    A3VRHybrid_proxyBeltAnimationLog = "";
    A3VRHybrid_proxyBeltAnimations = [];
    A3VRHybrid_proxyGunParticleLog = "";
};

A3VRHybrid_fnc_proxyCreateVisual = {
    params ["_weapon", "_state", "_signature", "_position"];
    call A3VRHybrid_fnc_proxyDeleteVisual;
    private _config = configFile >> "CfgWeapons" >> _weapon;
    private _model = getText (_config >> "model");
    if (_model isEqualTo "") exitWith {
        diag_log format ["[A3VR] Proxy weapon has no model: %1", _weapon];
    };
    if ((_model select [0, 1]) isEqualTo "\") then {
        _model = _model select [1];
    };
    A3VRHybrid_proxyWeaponModel = _model;
    A3VRHybrid_proxyGeometry = createSimpleObject [_model, _position, true];
    if (isNull A3VRHybrid_proxyGeometry) exitWith {
        diag_log format ["[A3VR] Proxy cannot load weapon model: %1", _model];
    };
    [A3VRHybrid_proxyGeometry, _config, _weapon] call
        A3VRHybrid_fnc_proxyApplyConfigAppearance;

    private _muzzleName = getText (_config >> "muzzlePos");
    private _backName = getText (_config >> "muzzleEnd");
    if (_muzzleName isEqualTo "") then {_muzzleName = "usti hlavne";};
    if (_backName isEqualTo "") then {_backName = "konec hlavne";};
    private _muzzle = A3VRHybrid_proxyGeometry selectionPosition
        [_muzzleName, "Memory"];
    private _back = A3VRHybrid_proxyGeometry selectionPosition
        [_backName, "Memory"];
    private _modelForward = _muzzle vectorDiff _back;
    if (vectorMagnitude _modelForward < 0.05) then {
        private _bounds = boundingBoxReal A3VRHybrid_proxyGeometry;
        private _minimum = _bounds # 0;
        private _maximum = _bounds # 1;
        private _extentX = (_maximum # 0) - (_minimum # 0);
        private _extentY = (_maximum # 1) - (_minimum # 1);
        if (_extentX > _extentY) then {
            _modelForward = [1, 0, 0];
            _muzzle = [_maximum # 0, 0, 0];
        } else {
            _modelForward = [0, 1, 0];
            _muzzle = [0, _maximum # 1, 0];
        };
    };
    _modelForward = vectorNormalized _modelForward;
    private _modelUp = [0, 0, 1] vectorDiff
        (_modelForward vectorMultiply
        ([0, 0, 1] vectorDotProduct _modelForward));
    if (vectorMagnitude _modelUp < 0.1) then {_modelUp = [0, 1, 0];};
    _modelUp = vectorNormalized _modelUp;
    A3VRHybrid_proxyModelForward = +_modelForward;
    A3VRHybrid_proxyModelUp = +_modelUp;
    A3VRHybrid_proxyModelMuzzle = +_muzzle;
    A3VRHybrid_proxyGeometry hideObject true;

    A3VRHybrid_proxyVisual = "WeaponHolderSimulated" createVehicleLocal
        (ASLToAGL _position);
    private _cargo = [];
    if (!isNull A3VRHybrid_proxyVisual) then {
        A3VRHybrid_proxyVisual allowDamage false;
        A3VRHybrid_proxyVisual enableSimulation false;
        A3VRHybrid_proxyVisual addWeaponWithAttachmentsCargo [_state, 1];
        _cargo = weaponsItemsCargo A3VRHybrid_proxyVisual;
    };

    private _selection = if (!isNull A3VRHybrid_proxyVisual) then {
        [A3VRHybrid_proxyVisual] call A3VRHybrid_fnc_proxyFindHolderProxy
    } else {""};
    if (_selection isNotEqualTo "") then {
        A3VRHybrid_proxyVisualMount = [
            A3VRHybrid_proxyVisual, _selection, _modelForward, _modelUp,
            _muzzle
        ] call A3VRHybrid_fnc_proxyResolveMount;
    };

    if (count A3VRHybrid_proxyVisualMount >= 4 && {count _cargo > 0}) then {
        A3VRHybrid_proxyVisualComposite = true;
    } else {
        // A holder without an exposed proxy cannot be aligned safely. Fall
        // back to the weapon P3D and rebuild its configured inventory slots.
        // This is the proven v9 path and avoids the incomplete base-weapon
        // model that v10 displayed without optics, muzzle device or magazine.
        if (!isNull A3VRHybrid_proxyVisual) then {
            deleteVehicle A3VRHybrid_proxyVisual;
        };
        A3VRHybrid_proxyVisual = A3VRHybrid_proxyGeometry;
        A3VRHybrid_proxyGeometry = objNull;
        A3VRHybrid_proxyVisual hideObject false;
        A3VRHybrid_proxyVisualMount = [
            [0, 0, 0], _modelForward, _modelUp, _muzzle, "raw-model"
        ];
        A3VRHybrid_proxyFlashSelections = [
            A3VRHybrid_proxyVisual
        ] call A3VRHybrid_fnc_proxyCollectFlashSelections;
        A3VRHybrid_proxyFlashAnimations =
            (animationNames A3VRHybrid_proxyVisual) select {
                private _name = toLower _x;
                ((_name find "flash") >= 0 ||
                 {(_name find "zasleh") >= 0}) &&
                {(_name find "hide") >= 0}
            };
        [A3VRHybrid_proxyVisual, true] call
            A3VRHybrid_fnc_proxyHideMuzzleFlash;
        [_weapon, _state, A3VRHybrid_proxyVisual, _position] call
            A3VRHybrid_fnc_proxyCreateAttachments;
        [_state, A3VRHybrid_proxyVisual, _position] call
            A3VRHybrid_fnc_proxyCreateMagazine;
    };

    A3VRHybrid_proxyWeaponClass = _weapon;
    A3VRHybrid_proxyWeaponState = +_state;
    A3VRHybrid_proxyVisualSignature = _signature;
    A3VRHybrid_proxySuppressed = count _state > 1 &&
        {(_state # 1) isEqualType ""} && {(_state # 1) isNotEqualTo ""};
    diag_log format [
        "[A3VR] Proxy visual weapon=%1 composite=%2 holderProxy=%3 attachments=%4 state=%5",
        _weapon, A3VRHybrid_proxyVisualComposite,
        A3VRHybrid_proxyVisualMount param [4, ""],
        A3VRHybrid_proxyAttachments apply {_x param [4, ""]}, _state
    ];
};

A3VRHybrid_fnc_proxyDeleteRig = {
    if (!isNil "A3VRHybrid_fnc_proxyDeleteHands") then {
        call A3VRHybrid_fnc_proxyDeleteHands;
    };
    if (!isNull A3VRHybrid_proxyRig &&
        {A3VRHybrid_proxyRigFiredEH >= 0}) then {
        A3VRHybrid_proxyRig removeEventHandler
            ["FiredMan", A3VRHybrid_proxyRigFiredEH];
    };
    A3VRHybrid_proxyRigFiredEH = -1;
    if (!isNull A3VRHybrid_proxyRig) then {
        deleteVehicle A3VRHybrid_proxyRig;
    };
    A3VRHybrid_proxyRig = objNull;
    A3VRHybrid_proxyRigMount = [];
    A3VRHybrid_proxyRigReady = false;
    A3VRHybrid_proxyLoadoutSignature = "";
};

/*
    hideSelection only masks named selections on simple objects; it cannot crop
    the authoritative Man/createAgent. The optional clone mode therefore makes
    two local class-based simple objects from the avatar's current uniform class,
    copies the live textures/materials, hides every known selection and reveals
    only the left/right arm chains. Each rigid cutout is then anchored by its
    hand basis directly to the controller weapon. This deliberately never
    changes player collision, damage, inventory or AI visibility.

    Arma does not expose a supported way to copy the live Man skeletal pose into
    a simple object. The appearance/loadout is refreshed in real time, while the
    cropped arm itself is a rigid visual experiment and stays disabled by
    default.
*/
A3VRHybrid_fnc_proxyDeleteHands = {
    {
        private _object = _x param [0, objNull];
        if (!isNull _object) then {deleteVehicle _object;};
    } forEach A3VRHybrid_proxyHandVisuals;
    A3VRHybrid_proxyHandVisuals = [];
    A3VRHybrid_proxyHandSignature = "";
};

A3VRHybrid_fnc_proxyHandBasis = {
    params ["_hand", "_index", "_thumb"];
    private _forward = _index vectorDiff _hand;
    if (vectorMagnitude _forward < 0.002) then {
        _forward = [0, 1, 0];
    } else {_forward = vectorNormalized _forward;};
    private _side = _thumb vectorDiff _hand;
    _side = _side vectorDiff
        (_forward vectorMultiply (_side vectorDotProduct _forward));
    if (vectorMagnitude _side < 0.002) then {
        _side = [1, 0, 0];
    } else {_side = vectorNormalized _side;};
    private _up = vectorNormalized (_side vectorCrossProduct _forward);
    [_forward, _up]
};

A3VRHybrid_fnc_proxyCreateHands = {
    params ["_rig"];
    if (isNull _rig) exitWith {};
    private _enabled = (missionNamespace getVariable [
        "A3VRHybrid_settingHandsRig", "off"]) isEqualTo "clone";
    if (!_enabled) exitWith {call A3VRHybrid_fnc_proxyDeleteHands;};

    private _modelInfo = getModelInfo _rig;
    private _model = _modelInfo param [1, ""];
    private _uniform = uniform _rig;
    private _avatarClass = getText (
        configFile >> "CfgWeapons" >> _uniform >> "ItemInfo" >>
        "uniformClass");
    if (_avatarClass isEqualTo "" ||
        {!isClass (configFile >> "CfgVehicles" >> _avatarClass)}) then {
        _avatarClass = typeOf _rig;
    };
    private _textures = getObjectTextures _rig;
    private _materials = getObjectMaterials _rig;
    private _signature = str [
        typeOf _rig, _avatarClass, _uniform, _model, _textures, _materials];
    if (_signature isEqualTo A3VRHybrid_proxyHandSignature &&
        {count A3VRHybrid_proxyHandVisuals isEqualTo 2}) exitWith {};
    call A3VRHybrid_fnc_proxyDeleteHands;
    if (_model isEqualTo "" || {_avatarClass isEqualTo ""}) exitWith {
        diag_log "[A3VR] Avatar arm cutout: rig model/class unavailable";
    };

    {
        _x params ["_sideName", "_hand", "_index", "_thumb",
            "_selectionTokens", "_forwardOffset", "_rightOffset",
            "_upOffset"];
        // Class-based simple objects retain type information and accept the
        // live avatar textures. Raw P3D super-simple objects discard that
        // retexturing on many Man models.
        private _object = createSimpleObject [
            _avatarClass, getPosASL _rig, true];
        if (!isNull _object) then {
            {
                _object setObjectTexture [_forEachIndex, _x];
            } forEach _textures;
            {
                _object setObjectMaterial [_forEachIndex, _x];
            } forEach _materials;

            private _names = [];
            {
                {
                    _names pushBackUnique _x;
                } forEach (_object selectionNames _x);
            } forEach [0, 1, 2, 3, 4, 5, 6];
            {
                _object hideSelection [_x, true];
            } forEach _names;
            private _kept = _names select {
                private _selectionName = toLower _x;
                (_selectionTokens findIf {
                    (_selectionName find _x) >= 0
                }) >= 0
            };
            // ArmaMan variants commonly gate limb vertices behind these render
            // sections in addition to named skeleton selections.
            {
                private _support = _x;
                private _match = _names findIf {
                    (toLower _x) isEqualTo _support
                };
                if (_match >= 0) then {
                    _kept pushBackUnique (_names # _match);
                };
            } forEach ["hl", "injury_hands"];
            {
                _object hideSelection [_x, false];
            } forEach _kept;

            private _handPosition = selectionPosition [_object, _hand, 0];
            private _basis = [
                _handPosition,
                selectionPosition [_object, _index, 0],
                selectionPosition [_object, _thumb, 0]
            ] call A3VRHybrid_fnc_proxyHandBasis;
            A3VRHybrid_proxyHandVisuals pushBack [
                _object, _sideName, _hand, _index, _thumb, _handPosition,
                _basis # 0, _basis # 1, _kept,
                _forwardOffset, _rightOffset, _upOffset
            ];
        };
    } forEach [
        ["left", "lefthand", "lefthandindex1", "lefthandthumb1",
            ["leftshoulder", "leftarm", "leftforearm", "lefthand",
             "lshoulder", "l_arm", "l_forearm", "l_hand"],
            0.30, -0.025, -0.055],
        ["right", "righthand", "righthandindex1", "righthandthumb1",
            ["rightshoulder", "rightarm", "rightforearm", "righthand",
             "rshoulder", "r_arm", "r_forearm", "r_hand"],
            -0.015, 0.015, -0.025]
    ];
    A3VRHybrid_proxyHandSignature = _signature;
    diag_log format [
        "[A3VR] Avatar arm cutout class=%1 uniform=%2 model=%3 count=%4 selections=%5",
        _avatarClass, _uniform, _model, count A3VRHybrid_proxyHandVisuals,
        A3VRHybrid_proxyHandVisuals apply {_x param [8, []]}
    ];
};

A3VRHybrid_fnc_proxyConfigureHandsRig = {
    params ["_rig"];
    if (isNull _rig) exitWith {};
    // A normal Man object cannot be selection-masked with hideSelection.
    _rig hideObject true;
    [_rig] call A3VRHybrid_fnc_proxyCreateHands;
};

A3VRHybrid_fnc_proxyUpdateHands = {
    params ["_weaponOrigin", "_weaponForward", "_weaponUp"];
    private _rig = A3VRHybrid_proxyRig;
    if (isNull _rig) exitWith {};
    if ((missionNamespace getVariable [
        "A3VRHybrid_settingHandsRig", "off"]) isNotEqualTo "clone") exitWith {
        call A3VRHybrid_fnc_proxyDeleteHands;
    };
    [_rig] call A3VRHybrid_fnc_proxyCreateHands;
    private _weaponRight = vectorNormalized
        (_weaponForward vectorCrossProduct _weaponUp);
    _weaponUp = vectorNormalized
        (_weaponRight vectorCrossProduct _weaponForward);
    {
        _x params ["_object", "_sideName", "_hand", "_index", "_thumb",
            "_localHand", "_localForward", "_localUp", "_kept",
            "_forwardOffset", "_rightOffset", "_upOffset"];
        if (!isNull _object) then {
            private _targetHand = _weaponOrigin
                vectorAdd (_weaponForward vectorMultiply _forwardOffset)
                vectorAdd (_weaponRight vectorMultiply _rightOffset)
                vectorAdd (_weaponUp vectorMultiply _upOffset);
            [_object,
                [_localHand, _localForward, _localUp, _localHand, _hand],
                _targetHand, _weaponForward, _weaponUp
            ] call A3VRHybrid_fnc_proxyPlaceObject;
        };
    } forEach A3VRHybrid_proxyHandVisuals;
};

A3VRHybrid_fnc_proxySetRenderMode = {
    private _hands = (missionNamespace getVariable [
        "A3VRHybrid_settingHandsRig", "off"]) isEqualTo "clone";
    if (!isNull A3VRHybrid_proxyRig) then {
        A3VRHybrid_proxyRig hideObject true;
    };
    // The equipped weapon remains the exact generative proxy visual. Only the
    // two optional arm cutouts render; the complete Man rig never does.
    if (!isNull A3VRHybrid_proxyVisual) then {
        A3VRHybrid_proxyVisual hideObject false;
    };
    {
        private _object = _x param [0, objNull];
        if (!isNull _object) then {
            _object hideObject false;
        };
    } forEach A3VRHybrid_proxyAttachments;
    {
        private _object = _x param [0, objNull];
        if (!isNull _object) then {_object hideObject (!_hands);};
    } forEach A3VRHybrid_proxyHandVisuals;
};

/* Emit Bohemia's own weapon cloudlet at the controller muzzle. Native emitters
   created by a hidden Man are not mission objects and cannot be detached --
   the old relocation path therefore moved zero sources and left smoke in the
   air. This uses the stock CfgCloudlets classes and the authoritative muzzle
   basis only after FiredMan proves that a real shot occurred. */
A3VRHybrid_fnc_proxyPulseNativeMuzzleSmoke = {
    params ["_weapon", "_muzzle", "_mode"];
    private _position = +A3VRHybrid_proxyMuzzlePosition;
    private _forward = vectorNormalized A3VRHybrid_proxyMuzzleDirection;
    private _up = vectorNormalized A3VRHybrid_proxyMuzzleUp;
    if (count _position < 3 || {vectorMagnitude _forward < 0.5}) exitWith {};
    private _profile = [[_weapon, _muzzle, _mode]] call
        A3VRHybrid_fnc_proxyFireProfile;
    private _cloudlet = [
        "A3VR_RifleMuzzleCloud", "A3VR_MachineGunMuzzleCloud"
    ] select (_profile # 0);
    if (!isClass (configFile >> "CfgCloudlets" >> _cloudlet)) then {
        _cloudlet = "A3VR_RifleMuzzleCloud";
    };
    private _source = "#particlesource" createVehicleLocal
        (ASLToAGL _position);
    if (isNull _source) exitWith {};
    _source setPosWorld _position;
    _source setVectorDirAndUp [_forward, _up];
    _source setParticleClass _cloudlet;
    private _life = if (A3VRHybrid_proxySuppressed) then {0.012} else {0.024};
    [_source, _life] spawn {
        params ["_source", "_life"];
        uiSleep _life;
        if (!isNull _source) then {deleteVehicle _source;};
    };
    private _signature = str [_weapon, _cloudlet];
    if (_signature isNotEqualTo A3VRHybrid_proxyGunParticleLog) then {
        A3VRHybrid_proxyGunParticleLog = _signature;
        diag_log format [
            "[A3VR] Proxy native cloudlet weapon=%1 class=%2",
            _weapon, _cloudlet];
    };
};

A3VRHybrid_fnc_proxyHandleFiredProjectile = {
    params ["_source", "_weapon", "_muzzle", "_mode", "_ammo",
        "_magazine", "_projectile"];
    if (!A3VRHybrid_proxyActive || {isNull player}) exitWith {};
    // FiredMan is the sole proof that Arma accepted and produced a shot. Never
    // expose flash/smoke from the controller request itself: pump actions and
    // empty weapons can reject forceWeaponFire while the trigger is clicking.
    A3VRHybrid_proxyLastShot = diag_tickTime;
    A3VRHybrid_proxyAcceptedShotSequence =
        A3VRHybrid_proxyAcceptedShotSequence + 1;
    if (_source isEqualTo A3VRHybrid_proxyRig &&
        {_muzzle isNotEqualTo ""}) then {
        // The hidden rig and real player consume exactly one mirrored round.
        player setAmmo [_muzzle, ((player ammo _muzzle) - 1) max 0];
    };
    if (!isNull _projectile) then {
        _projectile disableCollisionWith _source;
        _projectile disableCollisionWith player;
        _projectile disableCollisionWith vehicle player;
        {
            private _object = _x param [0, objNull];
            if (!isNull _object) then {
                _projectile disableCollisionWith _object;
            };
        } forEach A3VRHybrid_proxyAttachments;
        {
            if (!isNull _x) then {_projectile disableCollisionWith _x;};
        } forEach A3VRHybrid_proxyHandVisuals;
        if (!isNull A3VRHybrid_proxyVisual) then {
            _projectile disableCollisionWith A3VRHybrid_proxyVisual;
        };
        if (!isNull A3VRHybrid_proxyGeometry) then {
            _projectile disableCollisionWith A3VRHybrid_proxyGeometry;
        };
        _projectile setShotParents [vehicle player, player];
        private _speed = vectorMagnitude (velocity _projectile);
        _projectile setVectorDir A3VRHybrid_proxyMuzzleDirection;
        // Start beyond the visible muzzle/receiver geometry. The previous
        // two-centimetre offset let long weapons collide with their own proxy
        // before disableCollisionWith had propagated through PhysX.
        private _spawnPosition = A3VRHybrid_proxyMuzzlePosition vectorAdd
            (A3VRHybrid_proxyMuzzleDirection vectorMultiply 0.12);
        _projectile setPosWorld _spawnPosition;
        if (_speed > 0.1) then {
            _projectile setVelocity
                ((A3VRHybrid_proxyMuzzleDirection vectorMultiply _speed)
                vectorAdd velocity player);
        };
    };
    [_weapon, _ammo] call A3VRHybrid_fnc_proxyAddRecoil;
    "A3VRHybridCore" callExtension "haptic:shot";
    call A3VRHybrid_fnc_proxyPulseMuzzleFlash;
    if (_source isEqualTo A3VRHybrid_proxyRig) then {
        [_weapon, _muzzle, _mode] call
            A3VRHybrid_fnc_proxyPulseNativeMuzzleSmoke;
        [_ammo, _weapon, _muzzle] call A3VRHybrid_fnc_proxyEjectCasing;
    };
};

A3VRHybrid_fnc_proxyCreateRig = {
    call A3VRHybrid_fnc_proxyDeleteRig;
    if (isNull player || {!alive player}) exitWith {};
    A3VRHybrid_proxyRig = createAgent [
        typeOf player, ASLToAGL (getPosWorld player), [], 0, "CAN_COLLIDE"
    ];
    if (isNull A3VRHybrid_proxyRig) exitWith {
        diag_log "[A3VR] Proxy rig creation failed";
    };
    private _rig = A3VRHybrid_proxyRig;
    _rig allowDamage false;
    _rig setCaptive true;
    _rig enableReload false;
    _rig hideObject true;
    _rig disableCollisionWith player;
    {
        _rig disableAI _x;
    } forEach [
        "TARGET", "AUTOTARGET", "MOVE", "FSM", "PATH", "COVER",
        "AUTOCOMBAT", "CHECKVISIBLE", "SUPPRESSION"
    ];
    private _ready = [_rig] call A3VRHybrid_fnc_proxyApplyRigLoadout;
    A3VRHybrid_proxyRigReady = _ready;
    // Record the attempted state even if a modded Arsenal loadout cannot be
    // applied to createAgent. Retrying the same failed state every frame would
    // cause visual flicker and log spam; firing safely falls back to player.
    A3VRHybrid_proxyLoadoutSignature =
        call A3VRHybrid_fnc_proxyLoadoutSignature;
    [_rig] call A3VRHybrid_fnc_proxyConfigureHandsRig;

    A3VRHybrid_proxyRigFiredEH = _rig addEventHandler ["FiredMan", {
        params ["_rig", "_weapon", "_muzzle", "_mode", "_ammo",
            "_magazine", "_projectile"];
        [_rig, _weapon, _muzzle, _mode, _ammo, _magazine, _projectile]
            call A3VRHybrid_fnc_proxyHandleFiredProjectile;
    }];
    diag_log format [
        "[A3VR] Proxy native rig created: %1 weapon=%2 ready=%3 freeSimulation=true",
        typeOf _rig, currentWeapon _rig, A3VRHybrid_proxyRigReady];
};

A3VRHybrid_fnc_proxySyncRig = {
    params [["_force", false]];
    private _signature = call A3VRHybrid_fnc_proxyLoadoutSignature;
    if (isNull A3VRHybrid_proxyRig || {_force} ||
        {_signature isNotEqualTo A3VRHybrid_proxyLoadoutSignature}) then {
        call A3VRHybrid_fnc_proxyCreateRig;
    };
    if (isNull A3VRHybrid_proxyRig) exitWith {
        A3VRHybrid_proxyRigMount = [];
    };
    [A3VRHybrid_proxyRig, currentWeapon player, currentWeaponMode player,
        currentMuzzle player] call A3VRHybrid_fnc_proxySelectWeapon;

    private _weapon = currentWeapon player;
    private _selection = [A3VRHybrid_proxyRig, _weapon] call
        A3VRHybrid_fnc_proxyWeaponProxyName;
    A3VRHybrid_proxyRigMount = [
        A3VRHybrid_proxyRig, _selection,
        A3VRHybrid_proxyModelForward, A3VRHybrid_proxyModelUp,
        A3VRHybrid_proxyModelMuzzle
    ] call A3VRHybrid_fnc_proxyResolveMount;
    [A3VRHybrid_proxyRig] call A3VRHybrid_fnc_proxyConfigureHandsRig;
    if (count A3VRHybrid_proxyRigMount < 4) then {
        diag_log format [
            "[A3VR] Proxy rig mount unavailable weapon=%1 selection=%2",
            _weapon, _selection];
    };
};

A3VRHybrid_fnc_proxyResolveTracking = {
    params ["_sample"];
    if (!(_sample isEqualType []) || {count _sample < 11} ||
        {!A3VRHybrid_proxyCalibrated}) exitWith {[]};
    private _state = _sample # 10;
    if (count _state < 2) exitWith {[]};
    private _pose = _state # 1;
    if (count _pose < 5 || {(_pose # 0) < 1} ||
        {(_pose # 1) < 1}) exitWith {[]};
    private _relative = (_pose # 2) vectorDiff
        A3VRHybrid_proxyReferenceHeadPosition;
    private _localPosition = [_relative] call A3VRHybrid_fnc_proxyToReference;
    private _localForward = [_pose # 3] call
        A3VRHybrid_fnc_proxyToReference;
    private _localUp = [_pose # 4] call A3VRHybrid_fnc_proxyToReference;
    private _position = (eyePos player) vectorAdd
        ([_localPosition] call A3VRHybrid_fnc_proxyToWorld);
    private _forward = vectorNormalized
        ([_localForward] call A3VRHybrid_fnc_proxyToWorld);
    private _up = vectorNormalized
        ([_localUp] call A3VRHybrid_fnc_proxyToWorld);
    private _right = vectorNormalized (_forward vectorCrossProduct _up);
    _up = vectorNormalized (_right vectorCrossProduct _forward);
    [_position, _forward, _up]
};

A3VRHybrid_fnc_proxyForceNativeHud = {
    // Scripted cameras can render Arma's native HUD and drawIcon3D channels,
    // but only when both cameraEffectEnableHUD and the corresponding showHUD
    // flags are enabled. Preserve the mission/player state and lift only the
    // channels required for task markers, group indicators and action icons.
    // Applying menu settings while native must never alter the mission HUD.
    // During activation the camera already exists before this function runs.
    if (isNull A3VRHybrid_proxyCamera) exitWith {
        A3VRHybrid_proxyHudForced = false;
    };
    private _enabled = missionNamespace getVariable [
        "A3VRHybrid_settingProxyHud", true];
    if (!_enabled) exitWith {
        if (A3VRHybrid_proxyHudForced &&
            {A3VRHybrid_proxyPreviousHud isEqualType []} &&
            {count A3VRHybrid_proxyPreviousHud > 0}) then {
            showHUD A3VRHybrid_proxyPreviousHud;
        };
        A3VRHybrid_proxyHudForced = false;
    };
    private _state = +shownHUD;
    while {count _state < 11} do {_state pushBack true;};
    private _required = +_state;
    {
        _required set [_x, true];
    } forEach [0, 1, 6, 7, 10];
    if !(_required isEqualTo _state) then {
        showHUD _required;
    };
    A3VRHybrid_proxyHudForced = true;
};

// Native task/squad indicators are evaluated relative to the authoritative
// player camera and are unreliable through a detached cameraEffect. Mirror the
// two navigation channels explicitly in Draw3D so they are anchored to the
// proxy camera. Nothing is created in the world and the layer can be disabled
// live from the A3VR settings menu.
A3VRHybrid_proxyMarkerDrawEH = addMissionEventHandler ["Draw3D", {
    if (!A3VRHybrid_proxyActive || {isNull player} ||
        {!(missionNamespace getVariable [
            "A3VRHybrid_settingProxyHud", true])}) exitWith {};

    private _playerPosition = getPosATLVisual player;
    {
        if (_x isNotEqualTo player && {alive _x}) then {
            private _position = _x modelToWorldVisual [0, 0, 2.05];
            private _distance = round (_playerPosition distance2D _position);
            drawIcon3D [
                "\a3\ui_f\data\map\vehicleicons\iconMan_ca.paa",
                [0.25, 0.78, 1.0, 0.88], _position,
                0.72, 0.72, 0,
                format ["%1  %2 m", name _x, _distance],
                2, 0.030, "RobotoCondensedBold", "center", false
            ];
        };
    } forEach (units group player);

    private _current = currentTask player;
    {
        private _state = toLower (taskState _x);
        if (_state in ["created", "assigned"]) then {
            private _destination = taskDestination _x;
            if (_destination isEqualType [] &&
                {count _destination >= 2}) then {
                private _position = +_destination;
                if (count _position < 3) then {_position pushBack 0;};
                // Empty task destinations use the world origin. Do not create
                // a misleading marker there.
                if (vectorMagnitude _position > 1) then {
                    private _description = taskDescription _x;
                    private _title = _description param [1, "Objective"];
                    if (_title isEqualTo "") then {_title = "Objective";};
                    private _distance = round (
                        _playerPosition distance2D _position);
                    private _assigned = _x isEqualTo _current;
                    drawIcon3D [
                        "\a3\ui_f\data\igui\cfg\simpletasks\types\default_ca.paa",
                        if (_assigned) then {
                            [1.0, 0.76, 0.12, 0.98]
                        } else {[1.0, 0.76, 0.12, 0.62]},
                        _position, 0.92, 0.92, 0,
                        format ["%1  %2 m", _title, _distance],
                        2, 0.034, "RobotoCondensedBold", "center", true
                    ];
                };
            };
        };
    } forEach (simpleTasks player);
}];

A3VRHybrid_fnc_proxyCleanup = {
    params [["_reason", "cleanup"]];
    if (A3VRHybrid_proxyState isNotEqualTo "NATIVE") then {
        ["EXITING", _reason] call A3VRHybrid_fnc_proxySetState;
    };
    "A3VRHybridCore" callExtension "proxy_mode:off";
    call A3VRHybrid_fnc_proxyClearHostileFireTracking;
    call A3VRHybrid_fnc_proxyDeleteAITarget;
    call A3VRHybrid_fnc_proxyDeleteRig;
    call A3VRHybrid_fnc_proxyDeleteVisual;
    if (!isNull A3VRHybrid_proxyCamera) then {
        // camDestroy does not terminate a full-screen camera effect.  Manual
        // native mode and vehicle transitions therefore always release BACK
        // before destroying the proxy camera.  During a real UI/cinematic
        // transition, preserve a campaign camera that has already taken over.
        private _forceCameraRelease = _reason in [
            "menu/native-request", "disabled", "disabled-idempotent",
            "vehicle-entry", "vehicle-transition", "player-killed", "death",
            "player-rebind", "cleanup"
        ];
        if (_forceCameraRelease ||
            {cameraOn isEqualTo A3VRHybrid_proxyCamera}) then {
            A3VRHybrid_proxyCamera cameraEffect ["TERMINATE", "BACK"];
        };
        camDestroy A3VRHybrid_proxyCamera;
    };
    if (A3VRHybrid_proxyPreviousHud isEqualType [] &&
        {count A3VRHybrid_proxyPreviousHud > 0}) then {
        showHUD A3VRHybrid_proxyPreviousHud;
    };
    if (!isNull A3VRHybrid_proxyOwner) then {
        if (alive A3VRHybrid_proxyOwner &&
            {vehicle A3VRHybrid_proxyOwner isEqualTo
                A3VRHybrid_proxyOwner}) then {
            private _velocity = velocity A3VRHybrid_proxyOwner;
            A3VRHybrid_proxyOwner setVelocity [0, 0, _velocity # 2];
            A3VRHybrid_proxyOwner setAnimSpeedCoef 1;
            if (A3VRHybrid_proxyMovementAction isNotEqualTo "") then {
                A3VRHybrid_proxyOwner switchMove "";
            };
        };
        if (A3VRHybrid_proxyPlayerDamageEH >= 0) then {
            A3VRHybrid_proxyOwner removeEventHandler
                ["Dammaged", A3VRHybrid_proxyPlayerDamageEH];
        };
        if (A3VRHybrid_proxyPlayerFiredEH >= 0) then {
            A3VRHybrid_proxyOwner removeEventHandler
                ["FiredMan", A3VRHybrid_proxyPlayerFiredEH];
        };
        A3VRHybrid_proxyOwner enableReload
            A3VRHybrid_proxyOriginalReloadEnabled;
        A3VRHybrid_proxyOwner hideObject
            A3VRHybrid_proxyOriginalHidden;
    };
    A3VRHybrid_proxyPlayerDamageEH = -1;
    A3VRHybrid_proxyPlayerFiredEH = -1;
    A3VRHybrid_proxyCamera = objNull;
    A3VRHybrid_proxyOwner = objNull;
    A3VRHybrid_proxyActive = false;
    A3VRHybrid_proxyCalibrated = false;
    A3VRHybrid_proxyLastButtons = 0;
    A3VRHybrid_proxyLastFireProfile = "";
    A3VRHybrid_proxyFirePending = false;
    A3VRHybrid_proxyBurstShotsRemaining = 0;
    A3VRHybrid_proxyNextShotAt = 0;
    A3VRHybrid_proxyAcceptedShotSequence = 0;
    A3VRHybrid_proxyFlashUntil = -10;
    A3VRHybrid_proxyReloadActive = false;
    A3VRHybrid_proxyReloadPhase = 0;
    A3VRHybrid_proxyReloadAnimations = [];
    A3VRHybrid_proxyReloadBaseline = [];
    A3VRHybrid_proxyReloadSawNativePhase = false;
    A3VRHybrid_proxyReloadFallback = false;
    A3VRHybrid_proxyReloadMagazineClass = "";
    A3VRHybrid_proxyAccessoryEnabled = false;
    A3VRHybrid_proxyAccessoryClass = "";
    A3VRHybrid_proxyFrozenTarget = [];
    A3VRHybrid_proxyLifecycleUnit = objNull;
    A3VRHybrid_proxyRecoilPitch = 0;
    A3VRHybrid_proxyRecoilPitchVelocity = 0;
    A3VRHybrid_proxyRecoilYaw = 0;
    A3VRHybrid_proxyRecoilYawVelocity = 0;
    A3VRHybrid_proxyRecoilBack = 0;
    A3VRHybrid_proxyRecoilBackVelocity = 0;
    A3VRHybrid_proxyWasMoving = false;
    A3VRHybrid_proxyMovementAction = "";
    A3VRHybrid_proxyPreviousHud = [];
    A3VRHybrid_proxyNextHudRefresh = 0;
    A3VRHybrid_proxyHudForced = false;
    missionNamespace setVariable [
        "A3VRHybrid_weaponVisualActive", false, false];
    ["NATIVE", _reason] call A3VRHybrid_fnc_proxySetState;
};

A3VRHybrid_fnc_proxyActivate = {
    params ["_head", ["_reason", "gameplay-ready"]];
    if (A3VRHybrid_proxyActive) exitWith {};
    ["ENTERING", _reason] call A3VRHybrid_fnc_proxySetState;
    [_head] call A3VRHybrid_fnc_proxyCalibrate;
    A3VRHybrid_proxyCamera = "camera" camCreate
        (ASLToAGL (eyePos player));
    if (isNull A3VRHybrid_proxyCamera) exitWith {
        A3VRHybrid_proxyCalibrated = false;
        diag_log "[A3VR] Proxy camera creation failed";
        ["NATIVE", "camera-create-failed"] call
            A3VRHybrid_fnc_proxySetState;
    };
    private _runtimeStatus = "A3VRHybridCore" callExtension "status";
    if ((_runtimeStatus find "depth SBS") < 0) then {
        A3VRHybrid_proxyCamera cameraEffect ["INTERNAL", "BACK"];
    };
    A3VRHybrid_proxyCamera camSetFov A3VRHybrid_proxyNormalFov;
    A3VRHybrid_proxyCamera camCommit 0;
    cameraEffectEnableHUD true;
    A3VRHybrid_proxyPreviousHud = +shownHUD;
    call A3VRHybrid_fnc_proxyForceNativeHud;
    A3VRHybrid_proxyNextHudRefresh = diag_tickTime + 0.75;
    showCinemaBorder false;
    A3VRHybrid_proxyOwner = player;
    A3VRHybrid_proxyLifecycleUnit = player;
    A3VRHybrid_proxyOriginalHidden = isObjectHidden player;
    A3VRHybrid_proxyOriginalReloadEnabled = reloadEnabled player;
    // Manual reload remains available, but the engine must not start one when
    // the last mirrored round reaches zero in the hidden proxy mode.
    player enableReload false;
    if (A3VRHybrid_proxyPlayerDamageEH >= 0) then {
        player removeEventHandler
            ["Dammaged", A3VRHybrid_proxyPlayerDamageEH];
    };
    if (A3VRHybrid_proxyPlayerFiredEH >= 0) then {
        player removeEventHandler
            ["FiredMan", A3VRHybrid_proxyPlayerFiredEH];
    };
    A3VRHybrid_proxyPlayerDamageEH = player addEventHandler ["Dammaged", {
        params ["_unit", "_selection", "_damage", "_hitIndex",
            "_hitPoint", "_shooter", "_projectile"];
        diag_log format [
            "[A3VR] Real player damaged selection=%1 damage=%2 hitPoint=%3 shooter=%4 projectile=%5 total=%6",
            _selection, _damage, _hitPoint, typeOf _shooter, _projectile,
            damage _unit
        ];
        if (!isNull _shooter) then {
            addCamShake [0.55, 0.10, 14];
        };
        A3VRHybrid_proxyLastNativeDamageAt = diag_tickTime;
        A3VRHybrid_proxyLastNativeDamageShooter = _shooter;
        private _projectileClass = if (_projectile isEqualType "") then {
            _projectile
        } else {
            if (_projectile isEqualType objNull && {!isNull _projectile}) then {
                typeOf _projectile
            } else {""}
        };
        A3VRHybrid_proxyLastNativeDamageAmmo = _projectileClass;
        if (diag_tickTime - A3VRHybrid_proxyLastDamageHapticAt > 0.14) then {
            A3VRHybrid_proxyLastDamageHapticAt = diag_tickTime;
            private _explosive = false;
            if (_projectileClass isNotEqualTo "") then {
                private _ammoConfig =
                    configFile >> "CfgAmmo" >> _projectileClass;
                _explosive =
                    getNumber (_ammoConfig >> "explosive") > 0.15 ||
                    {getNumber (_ammoConfig >> "indirectHit") > 2};
            };
            "A3VRHybridCore" callExtension (
                ["haptic:damage", "haptic:explosion"] select _explosive);
        };
    }];
    A3VRHybrid_proxyPlayerFiredEH = player addEventHandler ["FiredMan", {
        params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo",
            "_magazine", "_projectile"];
        [_unit, _weapon, _muzzle, _mode, _ammo, _magazine, _projectile]
            call A3VRHybrid_fnc_proxyHandleFiredProjectile;
    }];
    player hideObject true;
    A3VRHybrid_proxyLastButtons = 0;
    A3VRHybrid_proxyFirePending = false;
    A3VRHybrid_proxyBurstShotsRemaining = 0;
    A3VRHybrid_proxyNextShotAt = 0;
    A3VRHybrid_proxyLastDryFireAt = -10;
    A3VRHybrid_proxyFlashUntil = -10;
    A3VRHybrid_proxyWasMoving = false;
    A3VRHybrid_proxyMovementAction = "";
    player setAnimSpeedCoef 1;
    A3VRHybrid_proxyNextSync = 0;
    A3VRHybrid_proxyNextCombatVisibility = 0;
    A3VRHybrid_proxyRecoilPitch = 0;
    A3VRHybrid_proxyRecoilPitchVelocity = 0;
    A3VRHybrid_proxyRecoilYaw = 0;
    A3VRHybrid_proxyRecoilYawVelocity = 0;
    A3VRHybrid_proxyRecoilBack = 0;
    A3VRHybrid_proxyRecoilBackVelocity = 0;
    A3VRHybrid_proxyFrozenTarget = [];
    A3VRHybrid_proxyActive = true;
    missionNamespace setVariable [
        "A3VRHybrid_weaponVisualActive", true, false];
    "A3VRHybridCore" callExtension "proxy_mode:on";
    systemChat "A3VR weapon control: VR PROXY (grip+B for native)";
    ["PROXY", _reason] call A3VRHybrid_fnc_proxySetState;
    diag_log format [
        "[A3VR][Proxy] activated owner=%1 weapon=%2 reason=%3",
        A3VRHybrid_proxyOwner, currentWeapon player, _reason];
};

A3VRHybrid_fnc_setWeaponProxyEnabled = {
    params [["_enabled", true]];
    if (_enabled isEqualTo A3VRHybrid_proxyEnabled) exitWith {
        if (!_enabled && {A3VRHybrid_proxyActive}) then {
            ["disabled-idempotent"] call A3VRHybrid_fnc_proxyCleanup;
        };
    };
    A3VRHybrid_proxyEnabled = _enabled;
    if (!_enabled && {A3VRHybrid_proxyActive}) then {
        ["menu/native-request"] call A3VRHybrid_fnc_proxyCleanup;
    };
    systemChat format ["A3VR weapon control: %1",
        ["NATIVE MOTION", "VR PROXY"] select _enabled];
    diag_log format ["[A3VR] Weapon control mode: %1",
        ["native motion", "VR proxy"] select _enabled];
    if (!(isNil "A3VRHybrid_fnc_refreshSettingsMenu")) then {
        call A3VRHybrid_fnc_refreshSettingsMenu;
    };
};

A3VRHybrid_fnc_toggleWeaponProxy = {
    // Controller chords and menu buttons can be sampled in adjacent frames.
    if (diag_tickTime - A3VRHybrid_proxyLastToggleAt < 0.55) exitWith {};
    A3VRHybrid_proxyLastToggleAt = diag_tickTime;
    // Vehicles always use Arma's native camera/input path.  Keep the user's
    // on-foot preference unchanged so proxy mode can resume after exiting.
    if (!isNull player && {vehicle player isNotEqualTo player}) exitWith {
        systemChat "A3VR weapon control: NATIVE VEHICLE MODE";
        diag_log "[A3VR] Proxy toggle ignored while in vehicle";
    };
    [!A3VRHybrid_proxyEnabled] call
        A3VRHybrid_fnc_setWeaponProxyEnabled;
};

"A3VRHybridCore" callExtension "proxy_mode:off";
waitUntil {uiSleep 0.10; !isNull findDisplay 46};

A3VRHybrid_proxyEachFrame = addMissionEventHandler ["EachFrame", {
    private _sample = missionNamespace getVariable ["A3VRHybrid_tracking", []];
    private _uiOpen = missionNamespace getVariable [
        "A3VRHybrid_contextUi", false] || {visibleMap} ||
        {!isNull (findDisplay 49)} ||
        {!isNull (findDisplay 160)} || {!isNull (findDisplay 312)} ||
        {!isNull (findDisplay 602)};
    private _controlledUnit = call A3VRHybrid_fnc_proxyControlledUnit;
    private _valid = A3VRHybrid_proxyEnabled &&
        {missionNamespace getVariable [
            "A3VRHybrid_contextGameplay", false]} &&
        {_sample isEqualType []} && {count _sample >= 11} &&
        {!isNull player} && {alive player} &&
        {_controlledUnit isEqualTo player} &&
        {diag_tickTime >= A3VRHybrid_proxyVehicleEntryPendingUntil} &&
        {diag_tickTime >= A3VRHybrid_proxyUiRequestPendingUntil} &&
        {vehicle player isEqualTo player} && {!_uiOpen} &&
        {A3VRHybrid_proxyActive || {cameraView isEqualTo "INTERNAL"}};
    if (!_valid) exitWith {
        if (A3VRHybrid_proxyActive) then {
            private _reason = if (!A3VRHybrid_proxyEnabled) then {
                "disabled"
            } else {
                if (!(_controlledUnit isEqualTo player)) then {
                    "controlled-unit-changed"
                } else {
                    if (vehicle player isNotEqualTo player) then {
                        "vehicle-transition"
                    } else {
                        if (_uiOpen) then {"ui-or-cinematic"} else {
                            if (!alive player) then {"death"} else {
                                "gameplay-context-lost"
                            }
                        }
                    }
                }
            };
            [_reason] call A3VRHybrid_fnc_proxyCleanup;
        };
    };

    private _head = _sample # 4;
    if (count _head < 5 || {(_head # 0) < 1} ||
        {(_head # 1) < 1}) exitWith {
        if (A3VRHybrid_proxyActive) then {
            ["tracking-invalid"] call A3VRHybrid_fnc_proxyCleanup;
        };
    };
    if (!A3VRHybrid_proxyActive ||
        {!(A3VRHybrid_proxyOwner isEqualTo player)}) then {
        if (A3VRHybrid_proxyActive) then {
            ["player-rebind"] call A3VRHybrid_fnc_proxyCleanup;
        };
        [_head, "player-rebind"] call A3VRHybrid_fnc_proxyActivate;
    };
    if (!A3VRHybrid_proxyActive) exitWith {};
    // Campaign scripts can explicitly reveal the player after a cinematic.
    // Reassert the hidden native body while the proxy owns gameplay so only
    // one weapon is rendered. Cleanup restores it for the next cutscene.
    A3VRHybrid_proxyOwner hideObject true;
    if (!A3VRHybrid_proxyCalibrated) then {
        [_head] call A3VRHybrid_fnc_proxyCalibrate;
    };

    private _controller = _sample # 8;
    private _buttons = if (_controller isEqualType [] &&
        {count _controller >= 3}) then {round (_controller # 2)} else {0};

    // Direct addon-owned UI chords are reliable even when the Windows
    // keyboard focus or user's Arma key profile differs. Left grip is bit 512,
    // X/interact is bit 64 and Y/weapon swap is bit 32.
    private _uiModifier =
        (((floor (_buttons / 512)) mod 2) isEqualTo 1);
    private _mapChord = _uiModifier &&
        {(((floor (_buttons / 64)) mod 2) isEqualTo 1)};
    private _inventoryChord = _uiModifier &&
        {(((floor (_buttons / 32)) mod 2) isEqualTo 1)};
    if (!_mapChord) then {A3VRHybrid_proxyMapChordLatched = false;};
    if (!_inventoryChord) then {
        A3VRHybrid_proxyInventoryChordLatched = false;
    };
    if (_mapChord && {!A3VRHybrid_proxyMapChordLatched}) exitWith {
        A3VRHybrid_proxyMapChordLatched = true;
        A3VRHybrid_proxyLastButtons = _buttons;
        A3VRHybrid_proxyUiRequestPendingUntil = diag_tickTime + 1;
        ["map-request"] call A3VRHybrid_fnc_proxyCleanup;
        [] spawn {
            uiSleep 0;
            openMap [true, false];
        };
    };
    if (_inventoryChord &&
        {!A3VRHybrid_proxyInventoryChordLatched}) exitWith {
        A3VRHybrid_proxyInventoryChordLatched = true;
        A3VRHybrid_proxyLastButtons = _buttons;
        A3VRHybrid_proxyUiRequestPendingUntil = diag_tickTime + 1;
        ["inventory-request"] call A3VRHybrid_fnc_proxyCleanup;
        [] spawn {
            uiSleep 0;
            player action ["Gear", objNull];
        };
    };

    // Smooth turn rotates the stable room-to-world basis directly. Mouse
    // movement is disabled by native proxy mode. Clamp frame time so an RTT or
    // menu hitch cannot become a huge one-frame yaw jump, and use the same
    // Comfort/Normal/Fast setting exposed by the menu.
    if (_controller isEqualType [] && {count _controller >= 4} &&
        {abs (_controller # 3) > 0.18}) then {
        private _magnitude = abs (_controller # 3);
        private _normal = ((_magnitude - 0.18) / 0.82) min 1;
        private _sign = if ((_controller # 3) < 0) then {-1} else {1};
        private _turnSetting = missionNamespace getVariable [
            "A3VRHybrid_settingTurnRate", "normal"];
        private _turnRate = switch (_turnSetting) do {
            case "comfort": {60};
            case "fast": {150};
            default {100};
        };
        private _turnDelta = (diag_deltaTime max 0) min 0.05;
        A3VRHybrid_proxyWorldYaw = A3VRHybrid_proxyWorldYaw +
            (_sign * (_normal ^ 1.35) * _turnRate * _turnDelta);
        A3VRHybrid_proxyWorldForward = [
            sin A3VRHybrid_proxyWorldYaw,
            cos A3VRHybrid_proxyWorldYaw, 0];
        A3VRHybrid_proxyWorldRight = [
            cos A3VRHybrid_proxyWorldYaw,
            -sin A3VRHybrid_proxyWorldYaw, 0];
    };

    private _headLocalDirection = [_head # 3] call
        A3VRHybrid_fnc_proxyToReference;
    private _headLocalUp = [_head # 4] call
        A3VRHybrid_fnc_proxyToReference;
    private _headLocalOffset = [(_head # 2) vectorDiff
        A3VRHybrid_proxyReferenceHeadPosition] call
        A3VRHybrid_fnc_proxyToReference;
    private _worldHeadDirection = vectorNormalized
        ([_headLocalDirection] call A3VRHybrid_fnc_proxyToWorld);
    private _worldHeadUp = vectorNormalized
        ([_headLocalUp] call A3VRHybrid_fnc_proxyToWorld);
    private _worldHeadRight = vectorNormalized
        (_worldHeadDirection vectorCrossProduct _worldHeadUp);
    _worldHeadUp = vectorNormalized
        (_worldHeadRight vectorCrossProduct _worldHeadDirection);
    private _bodyEye = eyePos player;
    private _worldHeadPosition = _bodyEye vectorAdd
        ([_headLocalOffset] call A3VRHybrid_fnc_proxyToWorld);
    _worldHeadPosition = [_bodyEye, _worldHeadPosition] call
        A3VRHybrid_fnc_proxyClipHeadPosition;
    A3VRHybrid_proxyCamera setPosWorld _worldHeadPosition;
    A3VRHybrid_proxyCamera setVectorDirAndUp
        [_worldHeadDirection, _worldHeadUp];
    if (diag_tickTime >= A3VRHybrid_proxyNextHudRefresh) then {
        call A3VRHybrid_fnc_proxyForceNativeHud;
        A3VRHybrid_proxyNextHudRefresh = diag_tickTime + 0.75;
    };
    call A3VRHybrid_fnc_proxyRefreshCombatVisibility;
    call A3VRHybrid_fnc_proxyRelayIncomingBulletDamage;

    private _resolvedTarget = [_sample] call
        A3VRHybrid_fnc_proxyResolveTracking;
    // Controller poses can be absent for a frame while OpenXR changes focus or
    // confidence. Never erase the last good target and delete/recreate the
    // weapon on that transient dropout: that was the v10 weapon flicker.
    private _targetValid = count _resolvedTarget >= 3;
    if (A3VRHybrid_proxyMotionEnabled && {_targetValid}) then {
        A3VRHybrid_proxyFrozenTarget = +_resolvedTarget;
    } else {
        if (count A3VRHybrid_proxyFrozenTarget < 3 && {_targetValid}) then {
            A3VRHybrid_proxyFrozenTarget = +_resolvedTarget;
        };
    };
    private _target = if (A3VRHybrid_proxyMotionEnabled && {_targetValid}) then {
        _resolvedTarget
    } else {+A3VRHybrid_proxyFrozenTarget};
    if (count _target < 3) exitWith {};
    _target params ["_weaponOrigin", "_weaponForward", "_weaponUp"];

    private _activeWeapon = currentWeapon player;
    _weaponOrigin = [
        _worldHeadPosition, _weaponOrigin, _weaponForward, _activeWeapon
    ] call A3VRHybrid_fnc_proxyClipWeaponTarget;

    // Align the hidden body with the selected movement reference so the
    // controller-driven velocity and native movement action share a heading.
    private _bodyReference = _weaponForward;
    private _moveMagnitudeForBody = 0;
    if (_controller isEqualType [] && {count _controller >= 2}) then {
        _moveMagnitudeForBody = sqrt (
            ((_controller # 0) ^ 2) + ((_controller # 1) ^ 2));
    };
    if (_moveMagnitudeForBody > 0.18 &&
        {(missionNamespace getVariable [
            "A3VRHybrid_settingMovementDirection", "head"]) isEqualTo "head"}) then {
        _bodyReference = _worldHeadDirection;
    };
    private _horizontalWeapon = [
        _bodyReference # 0, _bodyReference # 1, 0];
    if (vectorMagnitude _horizontalWeapon > 0.05) then {
        _horizontalWeapon = vectorNormalized _horizontalWeapon;
        private _targetBodyYaw = (_horizontalWeapon # 0) atan2
            (_horizontalWeapon # 1);
        private _bodyYaw = getDir player;
        private _bodyError =
            ((_targetBodyYaw - _bodyYaw + 540) mod 360) - 180;
        if (abs _bodyError > 0.75) then {
            private _maximumBodyStep = 300 * diag_deltaTime;
            private _bodyStep = (_bodyError max (-_maximumBodyStep)) min
                _maximumBodyStep;
            player setDir ((_bodyYaw + _bodyStep + 360) mod 360);
        };
    };

    // Proxy movement uses shared controller telemetry instead of SendInput.
    // The pressure curve drives both collision-aware velocity and the native
    // leg/footstep cycle. Releasing the stick cancels that cycle and horizontal
    // velocity every frame, preventing the queued two-second walk-on.
    private _movedThisFrame = false;
    if (_controller isEqualType [] && {count _controller >= 3}) then {
        private _moveX = _controller # 0;
        private _moveY = _controller # 1;
        private _moveMagnitude = sqrt
            ((_moveX * _moveX) + (_moveY * _moveY));
        if (_moveMagnitude > 0.18) then {
            _movedThisFrame = true;
            private _moveScale = ((((_moveMagnitude - 0.18) / 0.82) max 0)
                min 1) ^ 1.35;
            private _moveForward = +A3VRHybrid_proxyWorldForward;
            if ((missionNamespace getVariable [
                "A3VRHybrid_settingMovementDirection", "head"])
                isEqualTo "head") then {
                _moveForward = [
                    _worldHeadDirection # 0,
                    _worldHeadDirection # 1, 0];
                if (vectorMagnitude _moveForward < 0.05) then {
                    _moveForward = +A3VRHybrid_proxyWorldForward;
                } else {
                    _moveForward = vectorNormalized _moveForward;
                };
            };
            private _moveRight = vectorNormalized
                (_moveForward vectorCrossProduct [0, 0, 1]);
            private _sprint =
                (((floor (_buttons / 4)) mod 2) isEqualTo 1);
            private _speed = switch (stance player) do {
                case "PRONE": {0.85};
                case "CROUCH": {1.75};
                default {if (_sprint) then {5.4} else {3.35}};
            };
            private _direction =
                (_moveRight vectorMultiply (_moveX / _moveMagnitude))
                vectorAdd
                (_moveForward vectorMultiply (_moveY / _moveMagnitude));
            private _currentVelocity = velocity player;
            private _nearGround = isTouchingGround player;
            if (!_nearGround) then {
                private _groundStart = (getPosWorld player) vectorAdd
                    [0, 0, 0.20];
                private _groundEnd = _groundStart vectorDiff [0, 0, 0.72];
                private _groundHits = lineIntersectsSurfaces [
                    _groundStart, _groundEnd, player, A3VRHybrid_proxyRig,
                    true, 1, "GEOM", "NONE", true
                ];
                if (count _groundHits > 0) then {
                    private _groundNormal = vectorNormalized
                        ((_groundHits # 0) # 1);
                    _nearGround = (_groundNormal # 2) > 0.48;
                };
            };
            if (_nearGround) then {
                private _velocity = _direction vectorMultiply
                    (_speed * _moveScale);
                private _verticalVelocity = ((_currentVelocity # 2) max -0.65)
                    min 0.32;
                _velocity set [2, _verticalVelocity];
                _velocity = [_velocity] call
                    A3VRHybrid_fnc_proxyClipMovementVelocity;
                player setVelocity _velocity;
            };

            private _prefix = if (_sprint) then {"Fast"} else {"Slow"};
            private _suffix = if (abs _moveY >= abs _moveX) then {
                if (_moveY >= 0) then {"F"} else {"B"}
            } else {
                if (_moveX >= 0) then {"R"} else {"L"}
            };
            private _moveAction = _prefix + _suffix;
            if (_moveAction isNotEqualTo
                A3VRHybrid_proxyMovementAction) then {
                player playActionNow _moveAction;
                A3VRHybrid_proxyMovementAction = _moveAction;
            };
            // Slow the root-motion/footstep animation with thumbstick pressure
            // so it cannot flatten every non-zero input to the same walk pace.
            player setAnimSpeedCoef (((_moveScale max 0.04) *
                ([1, 1.12] select _sprint)) min 1.12);
        };
    };
    if (!_movedThisFrame) then {
        private _velocity = velocity player;
        player setVelocity [0, 0, _velocity # 2];
        player setAnimSpeedCoef 1;
        if (A3VRHybrid_proxyMovementAction isNotEqualTo "") then {
            // switchMove cancels the queued locomotion immediately; PlayerStand
            // waits for an action transition and was the source of the drift.
            player switchMove "";
            A3VRHybrid_proxyMovementAction = "";
        };
    };
    A3VRHybrid_proxyWasMoving = _movedThisFrame;

    private _recoilTarget = [
        _weaponOrigin, _weaponForward, _weaponUp
    ] call A3VRHybrid_fnc_proxyApplyRecoil;
    _recoilTarget params [
        "_weaponOrigin", "_weaponForward", "_weaponUp"];

    private _weapon = currentWeapon player;
    if (_weapon isEqualTo "") exitWith {
        call A3VRHybrid_fnc_proxyDeleteVisual;
    };
    private _state = [_weapon] call A3VRHybrid_fnc_proxyCurrentWeaponState;
    private _signature = str [
        _weapon,
        [_state] call A3VRHybrid_fnc_proxyStableWeaponState
    ];
    if (_signature isNotEqualTo A3VRHybrid_proxyVisualSignature ||
        {isNull A3VRHybrid_proxyVisual}) then {
        [_weapon, _state, _signature, _weaponOrigin] call
            A3VRHybrid_fnc_proxyCreateVisual;
        [true] call A3VRHybrid_fnc_proxySyncRig;
    };
    if (isNull A3VRHybrid_proxyVisual) exitWith {};

    private _visualPlacement = [
        A3VRHybrid_proxyVisual, A3VRHybrid_proxyVisualMount,
        _weaponOrigin, _weaponForward, _weaponUp
    ] call A3VRHybrid_fnc_proxyPlaceObject;
    call A3VRHybrid_fnc_proxySetRenderMode;
    [_weaponOrigin, _weaponForward, _weaponUp] call
        A3VRHybrid_fnc_proxyUpdateHands;
    // Track the real reload lifecycle without applying guessed animation
    // phases to arbitrary weapon models.
    call A3VRHybrid_fnc_proxyUpdateReloadVisual;
    call A3VRHybrid_fnc_proxyUpdateAmmoVisual;
    call A3VRHybrid_fnc_proxyUpdateNativeWeaponSources;
    [A3VRHybrid_proxyVisual,
        A3VRHybrid_proxySuppressed ||
        {diag_tickTime >= A3VRHybrid_proxyFlashUntil}
    ] call A3VRHybrid_fnc_proxyHideMuzzleFlash;
    call A3VRHybrid_fnc_proxyCleanupCasings;
    if (count _visualPlacement >= 3) then {
        [getPosWorld A3VRHybrid_proxyVisual,
         _visualPlacement # 1,
         _visualPlacement # 2] call
            A3VRHybrid_fnc_proxyPlaceAttachments;
    };
    call A3VRHybrid_fnc_proxyUpdateBipodVisual;

    private _muzzlePlacement = _visualPlacement;
    if (count _muzzlePlacement >= 3) then {
        A3VRHybrid_proxyMuzzleDirection = +_weaponForward;
        A3VRHybrid_proxyMuzzleUp = +_weaponUp;
        A3VRHybrid_proxyBaseMuzzlePosition = +(_muzzlePlacement # 0);
        A3VRHybrid_proxyMuzzlePosition = [
            +A3VRHybrid_proxyBaseMuzzlePosition,
            A3VRHybrid_proxyMuzzleDirection
        ] call A3VRHybrid_fnc_proxyResolveBallisticMuzzle;
    };
    // A free Man retains weapon cadence, but it cannot follow arbitrary
    // controller pitch/roll. Keep its engine effects behind and below the HMD;
    // FiredMan recreates the stock cloudlet and configured cartridge at the
    // exact visible muzzle. Moving this rig onto the weapon every frame was
    // the cause of the one-shot/full-auto stalls in the latest test.
    if (!isNull A3VRHybrid_proxyRig) then {
        private _rigParking = _worldHeadPosition vectorDiff
            (_worldHeadDirection vectorMultiply 2.6);
        _rigParking = _rigParking vectorDiff [0, 0, 1.4];
        A3VRHybrid_proxyRig setPosWorld _rigParking;
        A3VRHybrid_proxyRig setVectorDirAndUp [
            _worldHeadDirection, _worldHeadUp];
        A3VRHybrid_proxyRig setVelocity [0, 0, 0];
    };
    // Stable, versioned read-only bridge for optional visual companions such
    // as A3VR VR Optics. Consumers must not mutate the referenced visual.
    private _weaponRight = _weaponForward vectorCrossProduct _weaponUp;
    missionNamespace setVariable ["A3VRHybrid_weaponTransform_v1", [
        1,
        +A3VRHybrid_proxyMuzzlePosition,
        +A3VRHybrid_proxyMuzzleDirection,
        +A3VRHybrid_proxyMuzzleUp,
        +_weaponRight,
        _weapon,
        A3VRHybrid_proxyVisual
    ], false];

    private _previous = A3VRHybrid_proxyLastButtons;
    private _modifier =
        (((floor (_buttons / 512)) mod 2) isEqualTo 1);
    private _modifierOld =
        (((floor (_previous / 512)) mod 2) isEqualTo 1);
    private _fire = (((floor (_buttons / 1)) mod 2) isEqualTo 1);
    private _reloadRaw = (((floor (_buttons / 8)) mod 2) isEqualTo 1);
    private _modeRaw = (((floor (_buttons / 16)) mod 2) isEqualTo 1);
    private _reloadOldRaw =
        (((floor (_previous / 8)) mod 2) isEqualTo 1);
    private _modeOldRaw =
        (((floor (_previous / 16)) mod 2) isEqualTo 1);
    private _accessoryChord = _modifier && {_reloadRaw};
    private _accessoryChordOld = _modifierOld && {_reloadOldRaw};
    private _reload =
        _reloadRaw && {!_modifier} &&
        {!_modifierOld || {!_reloadOldRaw}};
    private _mode =
        _modeRaw && {!_modifier} && {!_modifierOld || {!_modeOldRaw}};
    private _swapRaw = (((floor (_buttons / 32)) mod 2) isEqualTo 1);
    private _swap = _swapRaw && {!_modifier};
    private _grenadeRaw =
        (((floor (_buttons / 256)) mod 2) isEqualTo 1);
    private _fireOld = (((floor (_previous / 1)) mod 2) isEqualTo 1);
    private _reloadOld = _reloadOldRaw && {!_modifierOld};
    private _modeOld = _modeOldRaw && {!_modifierOld};
    private _swapOldRaw =
        (((floor (_previous / 32)) mod 2) isEqualTo 1);
    private _swapOld = _swapOldRaw && {!_modifierOld};
    private _grenadeOldRaw =
        (((floor (_previous / 256)) mod 2) isEqualTo 1);
    // Grip+B belongs to the proxy/native toggle in the tracking loop. Keep
    // the chord consumed even if grip is released a frame before B.
    private _grenade =
        _grenadeRaw && {!_modifier} &&
        {!_modifierOld || {!_grenadeOldRaw}};
    private _grenadeOld = _grenadeOldRaw && {!_modifierOld};
    private _interact = (((floor (_buttons / 64)) mod 2) isEqualTo 1);
    private _interactOld =
        (((floor (_previous / 64)) mod 2) isEqualTo 1);

    if (_accessoryChord && {!_accessoryChordOld}) then {
        [_state param [2, ""]] call A3VRHybrid_fnc_proxyToggleAccessory;
    };

    if (_fire && {!_fireOld}) then {
        A3VRHybrid_proxyFirePending = true;
    };
    if (_fire || {A3VRHybrid_proxyBurstShotsRemaining > 0}) then {
        private _playerState = weaponState player;
        if (count _playerState >= 3) then {
            private _manualModes = [
                _playerState # 0, _playerState # 1
            ] call A3VRHybrid_fnc_proxyPlayerFireModes;
            if (count _manualModes > 0 &&
                {!((_playerState # 2) in _manualModes)}) then {
                player selectWeapon [
                    _playerState # 0, _playerState # 1,
                    _manualModes # 0
                ];
                _playerState = weaponState player;
            };
        };
        private _exactState = count _playerState >= 5 &&
            {(_playerState # 0) isEqualTo _weapon} &&
            {(_playerState # 1) isEqualTo currentMuzzle player} &&
            {(_playerState # 2) isEqualTo currentWeaponMode player};
        if (_exactState && {(_playerState # 4) <= 0} &&
            {_fire && {!_fireOld}}) then {
            [_playerState # 0, _playerState # 1] call
                A3VRHybrid_fnc_proxyDryFire;
            A3VRHybrid_proxyFirePending = false;
        };
        if (_exactState && {(_playerState # 4) > 0}) then {
            private _profile = [_playerState] call
                A3VRHybrid_fnc_proxyFireProfile;
            private _profileSignature = str [
                _playerState # 0, _playerState # 1,
                _playerState # 2, _profile
            ];
            if (_profileSignature isNotEqualTo
                A3VRHybrid_proxyLastFireProfile) then {
                A3VRHybrid_proxyLastFireProfile = _profileSignature;
                diag_log format [
                    "[A3VR] Proxy fire profile weapon=%1 muzzle=%2 mode=%3 automatic=%4 burst=%5 reloadTime=%6 config=%7",
                    _playerState # 0, _playerState # 1, _playerState # 2,
                    _profile # 0, _profile # 1, _profile # 2, _profile # 3
                ];
            };
            private _automatic = _profile # 0;
            private _burst = (_profile # 1) max 1;
            if (_burst > 1 && {A3VRHybrid_proxyFirePending} &&
                {A3VRHybrid_proxyBurstShotsRemaining <= 0}) then {
                A3VRHybrid_proxyBurstShotsRemaining = _burst;
            };
            // All paths use the current muzzle/mode's configured reloadTime.
            // The engine still accepts or rejects each actual shot through
            // forceWeaponFire and FiredMan remains the consumption authority.
            private _interval = ((_profile # 2) max 0.025) min 3;
            private _now = diag_tickTime;
            private _wantsShot = if (_automatic) then {
                _fire
            } else {
                A3VRHybrid_proxyFirePending ||
                {A3VRHybrid_proxyBurstShotsRemaining > 0}
            };
            if (_wantsShot) then {
                private _fireUnit = player;
                if (!isNull A3VRHybrid_proxyRig &&
                    {A3VRHybrid_proxyRigReady}) then {
                    private _rigState = weaponState A3VRHybrid_proxyRig;
                    private _rigExact = count _rigState >= 5 &&
                        {(_rigState # 0) isEqualTo (_playerState # 0)} &&
                        {(_rigState # 1) isEqualTo (_playerState # 1)} &&
                        {(_rigState # 2) isEqualTo (_playerState # 2)};
                    if (!_rigExact) then {
                        [A3VRHybrid_proxyRig, _playerState # 0,
                            _playerState # 2, _playerState # 1] call
                            A3VRHybrid_fnc_proxySelectWeapon;
                        _rigState = weaponState A3VRHybrid_proxyRig;
                        _rigExact = count _rigState >= 5 &&
                            {(_rigState # 0) isEqualTo (_playerState # 0)} &&
                            {(_rigState # 1) isEqualTo (_playerState # 1)} &&
                            {(_rigState # 2) isEqualTo (_playerState # 2)};
                    };
                    if (_rigExact) then {
                        // Mirror the complete loaded count before every request.
                        // The rig has no spare magazines and reload is disabled,
                        // so this cannot start a background reload sound.
                        A3VRHybrid_proxyRig setAmmo [
                            _playerState # 1, _playerState # 4];
                        _rigState = weaponState A3VRHybrid_proxyRig;
                    };
                    if (count _rigState >= 5 &&
                        {(_rigState # 0) isEqualTo (_playerState # 0)} &&
                        {(_rigState # 1) isEqualTo (_playerState # 1)} &&
                        {(_rigState # 2) isEqualTo (_playerState # 2)} &&
                        {(_rigState # 4) > 0}) then {
                        A3VRHybrid_proxyRig setVelocity [0, 0, 0];
                        _fireUnit = A3VRHybrid_proxyRig;
                    };
                };
                // The v13-proven authority path requests fire at the current
                // mode's reloadTime. Gating again on the hidden Man's round
                // animation phase stalls full-auto after one shot on several
                // DLC weapons even though their configured cadence is valid.
                private _roundReady = _now >= A3VRHybrid_proxyNextShotAt;
                if (_roundReady) then {
                    private _scheduled = A3VRHybrid_proxyNextShotAt;
                    if (_scheduled <= 0 ||
                        {_now - _scheduled > (_interval * 3)}) then {
                        _scheduled = _now;
                    };
                    private _acceptedBefore =
                        A3VRHybrid_proxyAcceptedShotSequence;
                    _fireUnit forceWeaponFire
                        [_playerState # 1, _playerState # 2];
                    // FiredMan runs synchronously when the engine accepts the
                    // request. Rejected requests (notably pump-action cycling)
                    // keep the input buffered and retry on a later frame;
                    // neither flash nor cadence advances without a real shot.
                    if (A3VRHybrid_proxyAcceptedShotSequence >
                        _acceptedBefore) then {
                        // Keep the schedule phase-locked. Using
                        // now+reloadTime on a 60 Hz loop rounded every interval
                        // upward and made automatics sound burst-like.
                        private _cadenceSteps = (floor (
                            ((_now - _scheduled) max 0) / _interval)) + 1;
                        A3VRHybrid_proxyNextShotAt = _scheduled +
                            (_cadenceSteps * _interval);
                        A3VRHybrid_proxyFirePending = false;
                        if (A3VRHybrid_proxyBurstShotsRemaining > 0) then {
                            A3VRHybrid_proxyBurstShotsRemaining =
                                A3VRHybrid_proxyBurstShotsRemaining - 1;
                        };
                    };
                };
            };
        } else {
            A3VRHybrid_proxyBurstShotsRemaining = 0;
        };
    };
    if (_reload && {!_reloadOld} && {!A3VRHybrid_proxyReloadActive}) then {
        A3VRHybrid_proxyBurstShotsRemaining = 0;
        private _reloadMuzzle = currentMuzzle player;
        private _reloadMagazine = [
            _weapon, _reloadMuzzle
        ] call A3VRHybrid_fnc_proxyFindReloadMagazine;
        if (_reloadMagazine isEqualTo "") then {
            systemChat "A3VR: no compatible ammunition available.";
            diag_log format [
                "[A3VR] Proxy reload rejected weapon=%1 muzzle=%2 reason=no-compatible-ammo",
                _weapon, _reloadMuzzle
            ];
        } else {
            private _accepted = player reload [
                _reloadMuzzle, _reloadMagazine];
            if (_accepted) then {
                [_weapon, _state, _reloadMagazine] call
                    A3VRHybrid_fnc_proxyBeginReloadVisual;
                A3VRHybrid_proxyNextSync = 0;
            } else {
                diag_log format [
                    "[A3VR] Proxy reload rejected weapon=%1 muzzle=%2 magazine=%3 reason=engine",
                    _weapon, _reloadMuzzle, _reloadMagazine
                ];
            };
        };
    };
    if (_mode && {!_modeOld}) then {
        private _muzzle = currentMuzzle player;
        private _modes = [_weapon, _muzzle] call
            A3VRHybrid_fnc_proxyPlayerFireModes;
        if (count _modes > 1) then {
            private _index = _modes find (currentWeaponMode player);
            if (_index < 0) then {_index = 0;};
            private _nextMode = _modes #
                ((_index + 1) mod (count _modes));
            player selectWeapon [_weapon, _muzzle, _nextMode];
        };
    };
    if (_swap && {!_swapOld}) then {
        private _weapons = [
            primaryWeapon player, handgunWeapon player,
            secondaryWeapon player
        ] select {_x isNotEqualTo ""};
        if (count _weapons > 0) then {
            private _index = _weapons findIf {
                (currentWeapon player) isEqualTo _x
            };
            private _next = _weapons #
                (if (_index < 0) then {0} else {
                    (_index + 1) mod (count _weapons)
                });
            [player, _next] call A3VRHybrid_fnc_proxySelectWeapon;
            A3VRHybrid_proxyVisualSignature = "";
            A3VRHybrid_proxyNextSync = 0;
        };
    };
    if (_grenade && {!_grenadeOld}) then {
        private _available = throwables player;
        if (count _available > 0) then {
            private _throwable = _available # 0;
            if (count _throwable > 1) then {
                private _throwMuzzle = _throwable # 1;
                player forceWeaponFire
                    [_throwMuzzle, _throwMuzzle];
            };
        };
    };
    if (_interact && {!_interactOld}) then {
        [_weaponOrigin, _weaponForward] call
            A3VRHybrid_fnc_proxyInteract;
    };
    A3VRHybrid_proxyLastButtons = _buttons;
    call A3VRHybrid_fnc_proxyValidateState;
}];

// A raw/simple-object weapon cannot emit the engine-managed laser from the
// hidden firing rig. Mirror IR pointers from the controller-aligned attachment
// every Draw3D frame while keeping native night-vision visibility rules.
A3VRHybrid_proxyLaserDrawEH = addMissionEventHandler ["Draw3D", {
    if (!A3VRHybrid_proxyActive ||
        {!A3VRHybrid_proxyAccessoryEnabled}) exitWith {};
    private _pointerClass = A3VRHybrid_proxyWeaponState param [2, ""];
    if (_pointerClass isEqualTo "" ||
        {_pointerClass isNotEqualTo A3VRHybrid_proxyAccessoryClass}) exitWith {};
    private _config = configFile >> "CfgWeapons" >> _pointerClass;
    private _isFlashlight =
        (toLower _pointerClass find "flashlight") >= 0 ||
        {isClass (_config >> "ItemInfo" >> "FlashLight")};
    if (_isFlashlight) exitWith {};
    private _origin = +A3VRHybrid_proxyMuzzlePosition;
    private _pointerIndex = A3VRHybrid_proxyAttachments findIf {
        private _slot = toLower (_x param [5, ""]);
        (_slot find "pointer") >= 0 || {(_slot find "side") >= 0}
    };
    if (_pointerIndex >= 0) then {
        private _pointerObject =
            (A3VRHybrid_proxyAttachments # _pointerIndex) param [0, objNull];
        if (!isNull _pointerObject) then {
            _origin = getPosWorld _pointerObject;
        };
    };
    drawLaser [
        _origin, A3VRHybrid_proxyMuzzleDirection,
        [0, 0, 1000], [], 4, 2, -1, true
    ];
}];

addMissionEventHandler ["MPEnded", {
    ["mission-ended-mp"] call A3VRHybrid_fnc_proxyCleanup;
}];
addMissionEventHandler ["Ended", {
    ["mission-ended"] call A3VRHybrid_fnc_proxyCleanup;
}];
addMissionEventHandler ["TeamSwitch", {
    if (A3VRHybrid_proxyActive) then {
        ["team-switch"] call A3VRHybrid_fnc_proxyCleanup;
    };
    A3VRHybrid_proxyCalibrated = false;
}];
addMissionEventHandler ["EntityRespawned", {
    params ["_newUnit", "_oldUnit"];
    if (A3VRHybrid_proxyActive && {
        A3VRHybrid_proxyOwner isEqualTo _oldUnit ||
        {A3VRHybrid_proxyLifecycleUnit isEqualTo _oldUnit}}) then {
        ["player-respawn"] call A3VRHybrid_fnc_proxyCleanup;
    };
    if (_newUnit isEqualTo player) then {
        A3VRHybrid_proxyCalibrated = false;
    };
}];
addMissionEventHandler ["EntityKilled", {
    params ["_killed"];
    if (A3VRHybrid_proxyActive && {
        _killed isEqualTo A3VRHybrid_proxyOwner}) then {
        ["player-killed"] call A3VRHybrid_fnc_proxyCleanup;
    };
}];

diag_log "[A3VR] Controller-absolute single-authority proxy initialized";
