/*
    Local VR weapon view. The authoritative player keeps the real weapon,
    inventory and fire controls. A generated visual copy (including current
    attachments) follows the right OpenXR aim pose while the native first-
    person body is hidden by a script camera.
*/
if (!hasInterface) exitWith {};

A3VR_weaponCamera = objNull;
A3VR_weaponProxy = objNull;
A3VR_weaponProxyClass = "";
A3VR_weaponProxySignature = "";
A3VR_weaponProxyComposite = false;
A3VR_weaponHiddenUnit = objNull;
A3VR_weaponActive = false;
A3VR_weaponCalibrated = false;
A3VR_weaponReferenceHeadPosition = [0, 0, 0];
A3VR_weaponReferenceRight = [1, 0, 0];
A3VR_weaponReferenceForward = [0, 1, 0];
A3VR_weaponReferenceUp = [0, 0, 1];
A3VR_weaponWorldRight = [1, 0, 0];
A3VR_weaponWorldForward = [0, 1, 0];
A3VR_weaponWorldUp = [0, 0, 1];
A3VR_weaponState = [];
A3VR_weaponStateSignature = "";
A3VR_weaponNextLoadoutCheck = 0;
A3VR_weaponHasMagnifiedOptic = false;
A3VR_weaponMuzzlePosition = [0, 0, 0];
A3VR_weaponMuzzleDirection = [0, 1, 0];
A3VR_weaponFiredHandler = -1;

A3VR_fnc_weaponToReference = {
    params ["_vector"];
    [
        _vector vectorDotProduct A3VR_weaponReferenceRight,
        _vector vectorDotProduct A3VR_weaponReferenceForward,
        _vector vectorDotProduct A3VR_weaponReferenceUp
    ]
};

A3VR_fnc_weaponToWorld = {
    params ["_vector"];
    (A3VR_weaponWorldRight vectorMultiply (_vector # 0)) vectorAdd
    (A3VR_weaponWorldForward vectorMultiply (_vector # 1)) vectorAdd
    (A3VR_weaponWorldUp vectorMultiply (_vector # 2))
};

A3VR_fnc_deleteWeaponProxy = {
    if (!isNull A3VR_weaponProxy) then { deleteVehicle A3VR_weaponProxy; };
    A3VR_weaponProxy = objNull;
    A3VR_weaponProxyClass = "";
    A3VR_weaponProxySignature = "";
    A3VR_weaponProxyComposite = false;
};

A3VR_fnc_cleanupWeaponProxy = {
    if (!isNull A3VR_weaponHiddenUnit && {A3VR_weaponFiredHandler >= 0}) then {
        A3VR_weaponHiddenUnit removeEventHandler ["FiredMan", A3VR_weaponFiredHandler];
    };
    A3VR_weaponFiredHandler = -1;
    call A3VR_fnc_deleteWeaponProxy;
    if (!isNull A3VR_weaponCamera) then {
        A3VR_weaponCamera cameraEffect ["TERMINATE", "BACK"];
        camDestroy A3VR_weaponCamera;
    };
    if (!isNull A3VR_weaponHiddenUnit) then { A3VR_weaponHiddenUnit hideObject false; };
    A3VR_weaponCamera = objNull;
    A3VR_weaponHiddenUnit = objNull;
    A3VR_weaponActive = false;
    A3VR_weaponCalibrated = false;
};

A3VR_fnc_createWeaponProxy = {
    params ["_weaponClass", "_weaponState", "_signature", "_position"];
    call A3VR_fnc_deleteWeaponProxy;
    if (_weaponClass isEqualTo "") exitWith {};

    if (count _weaponState >= 7) then {
        A3VR_weaponProxy = createVehicle ["WeaponHolderSimulated",
            ASLToAGL _position, [], 0, "CAN_COLLIDE"];
        if (!isNull A3VR_weaponProxy) then {
            A3VR_weaponProxy allowDamage false;
            A3VR_weaponProxy enableSimulation false;
            A3VR_weaponProxy addWeaponWithAttachmentsCargoGlobal [_weaponState, 1];
            A3VR_weaponProxyComposite = true;
        };
    };

    if (isNull A3VR_weaponProxy) then {
        private _model = getText (configFile >> "CfgWeapons" >> _weaponClass >> "model");
        if !(_model isEqualTo "") then {
            if ((_model select [0, 1]) isEqualTo "\") then { _model = _model select [1]; };
            A3VR_weaponProxy = createSimpleObject [_model, _position, true];
        };
    };
    if (!isNull A3VR_weaponProxy) then {
        A3VR_weaponProxy hideSelection ["zasleh", true];
        A3VR_weaponProxy hideSelection ["zasleh2", true];
        A3VR_weaponProxyClass = _weaponClass;
        A3VR_weaponProxySignature = _signature;
        diag_log format ["[A3VR] VR weapon class=%1 attachments=%2",
            _weaponClass, _weaponState];
    };
};

waitUntil { uiSleep 0.1; !isNull findDisplay 46 };

A3VR_weaponEachFrame = addMissionEventHandler ["EachFrame", {
    private _sample = missionNamespace getVariable ["A3VR_tracking", []];
    private _validPlayer = !isNull player && {alive player} &&
        {vehicle player isEqualTo player} && {cameraView isEqualTo "INTERNAL"};
    if (!_validPlayer || {count _sample < 9}) exitWith {
        if (A3VR_weaponActive) then { call A3VR_fnc_cleanupWeaponProxy; };
    };

    private _head = _sample # 4;
    private _rightHand = _sample # 6;
    if (count _head < 5 || {count _rightHand < 5} ||
        {!((_head # 0) isEqualTo 1)} || {!((_head # 1) isEqualTo 1)} ||
        {!((_rightHand # 0) isEqualTo 1)} || {!((_rightHand # 1) isEqualTo 1)})
        exitWith {};

    private _weaponClass = currentWeapon player;
    if (_weaponClass isEqualTo "") exitWith { call A3VR_fnc_deleteWeaponProxy; };

    if (_weaponClass != A3VR_weaponProxyClass ||
        {diag_tickTime >= A3VR_weaponNextLoadoutCheck} ||
        {isNull A3VR_weaponProxy}) then {
        private _weaponState = [];
        {
            if (count _x > 0 && {(_x # 0) isEqualTo _weaponClass}) exitWith {
                _weaponState = +_x;
            };
        } forEach (weaponsItems player);
        if (_weaponState isEqualTo []) then {
            _weaponState = [_weaponClass, "", "", "", [], [], ""];
        };
        private _magazine1 = if (count (_weaponState # 4) > 0)
            then {(_weaponState # 4) # 0} else {""};
        private _magazine2 = if (count (_weaponState # 5) > 0)
            then {(_weaponState # 5) # 0} else {""};
        A3VR_weaponState = +_weaponState;
        A3VR_weaponStateSignature = str [
            _weaponState # 0, _weaponState # 1, _weaponState # 2,
            _weaponState # 3, _magazine1, _magazine2, _weaponState # 6
        ];
        A3VR_weaponHasMagnifiedOptic = false;
        private _opticClass = _weaponState # 3;
        if !(_opticClass isEqualTo "") then {
            private _modes = configFile >> "CfgWeapons" >> _opticClass >>
                "ItemInfo" >> "OpticsModes";
            {
                private _zoom = getNumber (_x >> "opticsZoomMin");
                if (_zoom > 0 && {_zoom < 0.20}) exitWith {
                    A3VR_weaponHasMagnifiedOptic = true;
                };
            } forEach ("true" configClasses _modes);
        };
        A3VR_weaponNextLoadoutCheck = diag_tickTime + 0.25;
    };

    private _buttons = (_sample # 8) # 2;
    private _aimPressed = (((floor (_buttons / 2)) mod 2) isEqualTo 1);
    // Arma activates magnified/PiP optics through its native optics camera.
    // Fall back to that path while the grip is held; generic forced PiP is not
    // exposed for every vanilla and modded optic.
    if (_aimPressed && {A3VR_weaponHasMagnifiedOptic}) exitWith {
        if (A3VR_weaponActive) then { call A3VR_fnc_cleanupWeaponProxy; };
    };

    if (!A3VR_weaponActive) then {
        private _yaw = getDir player;
        A3VR_weaponWorldForward = [sin _yaw, cos _yaw, 0];
        A3VR_weaponWorldRight = [cos _yaw, -sin _yaw, 0];
        A3VR_weaponWorldUp = [0, 0, 1];
        A3VR_weaponCamera = "camera" camCreate (ASLToAGL eyePos player);
        A3VR_weaponCamera cameraEffect ["INTERNAL", "BACK"];
        A3VR_weaponCamera camSetFov 1.1811123;
        A3VR_weaponCamera camCommit 0;
        cameraEffectEnableHUD true;
        showCinemaBorder false;
        A3VR_weaponHiddenUnit = player;
        player hideObject true;
        A3VR_weaponFiredHandler = player addEventHandler ["FiredMan", {
            params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo",
                "_magazine", "_projectile"];
            if (!A3VR_weaponActive || {isNull _projectile}) exitWith {};
            private _speed = vectorMagnitude (velocity _projectile);
            if (_speed < 1) then { _speed = 800; };
            _projectile setPosASL A3VR_weaponMuzzlePosition;
            _projectile setVelocity
                ((A3VR_weaponMuzzleDirection vectorMultiply _speed) vectorAdd
                (velocity _unit));
            _projectile setShotParents [vehicle _unit, _unit];
        }];
        A3VR_weaponActive = true;
        A3VR_weaponCalibrated = false;
    };

    if (!A3VR_weaponCalibrated) then {
        A3VR_weaponReferenceHeadPosition = +(_head # 2);
        A3VR_weaponReferenceForward = vectorNormalized (_head # 3);
        A3VR_weaponReferenceUp = vectorNormalized (_head # 4);
        A3VR_weaponReferenceRight = vectorNormalized
            (A3VR_weaponReferenceForward vectorCrossProduct A3VR_weaponReferenceUp);
        A3VR_weaponCalibrated = true;
    };

    // The native mouse turn rotates the soldier. Adopt that heading only while
    // the right stick is deliberately held, so controller aiming itself does
    // not rotate the VR camera a second time.
    private _input = _sample # 8;
    if (count _input >= 4 && {abs (_input # 3) > 0.2}) then {
        private _yaw = getDir player;
        A3VR_weaponWorldForward = [sin _yaw, cos _yaw, 0];
        A3VR_weaponWorldRight = [cos _yaw, -sin _yaw, 0];
    };

    private _headDirection = [(_head # 3)] call A3VR_fnc_weaponToReference;
    private _headUp = [(_head # 4)] call A3VR_fnc_weaponToReference;
    private _headOffset = [(_head # 2) vectorDiff A3VR_weaponReferenceHeadPosition]
        call A3VR_fnc_weaponToReference;
    private _worldHeadDirection = vectorNormalized
        ([_headDirection] call A3VR_fnc_weaponToWorld);
    private _worldHeadUp = vectorNormalized ([_headUp] call A3VR_fnc_weaponToWorld);
    private _worldHeadPosition = (eyePos player) vectorAdd
        ([_headOffset] call A3VR_fnc_weaponToWorld);
    A3VR_weaponCamera setPosWorld _worldHeadPosition;
    A3VR_weaponCamera setVectorDirAndUp [_worldHeadDirection, _worldHeadUp];

    private _handDirection = [(_rightHand # 3)] call A3VR_fnc_weaponToReference;
    private _handUp = [(_rightHand # 4)] call A3VR_fnc_weaponToReference;
    private _handOffset = [(_rightHand # 2) vectorDiff A3VR_weaponReferenceHeadPosition]
        call A3VR_fnc_weaponToReference;
    private _worldHandDirection = vectorNormalized
        ([_handDirection] call A3VR_fnc_weaponToWorld);
    private _worldHandUp = vectorNormalized ([_handUp] call A3VR_fnc_weaponToWorld);
    private _upCandidate = _worldHeadUp vectorDiff
        (_worldHandDirection vectorMultiply
        (_worldHeadUp vectorDotProduct _worldHandDirection));
    if (vectorMagnitude _upCandidate < 0.1) then { _upCandidate = _worldHandUp; };
    private _weaponUp = vectorNormalized _upCandidate;
    private _weaponPosition = (eyePos player) vectorAdd
        ([_handOffset] call A3VR_fnc_weaponToWorld) vectorAdd
        (_worldHandDirection vectorMultiply 0.02) vectorAdd
        (_weaponUp vectorMultiply -0.02);

    if (_weaponClass != A3VR_weaponProxyClass ||
        {A3VR_weaponStateSignature != A3VR_weaponProxySignature} ||
        {isNull A3VR_weaponProxy}) then {
        [_weaponClass, A3VR_weaponState, A3VR_weaponStateSignature, _weaponPosition]
            call A3VR_fnc_createWeaponProxy;
    };
    if (!isNull A3VR_weaponProxy) then {
        private _modelDirection = if (A3VR_weaponProxyComposite) then {
            _worldHandDirection
        } else {
            vectorNormalized (_worldHandDirection vectorCrossProduct _worldHandUp)
        };
        A3VR_weaponProxy setVectorDirAndUp [_modelDirection, _weaponUp];
        A3VR_weaponProxy setPosWorld _weaponPosition;
        private _bounds = boundingBoxReal A3VR_weaponProxy;
        private _minimum = _bounds # 0;
        private _maximum = _bounds # 1;
        private _length = ((_maximum # 0) - (_minimum # 0)) max
            (((_maximum # 1) - (_minimum # 1)) max
            ((_maximum # 2) - (_minimum # 2)));
        if (_length < 0.2) then { _length = 1.0; };
        A3VR_weaponMuzzlePosition = _weaponPosition vectorAdd
            (_worldHandDirection vectorMultiply (_length * 0.55));
        A3VR_weaponMuzzleDirection = +_worldHandDirection;
    };
}];

addMissionEventHandler ["MPEnded", { call A3VR_fnc_cleanupWeaponProxy; }];
addMissionEventHandler ["Ended", { call A3VR_fnc_cleanupWeaponProxy; }];
