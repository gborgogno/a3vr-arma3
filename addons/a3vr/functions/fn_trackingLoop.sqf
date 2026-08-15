/*
    Tracking-only diagnostic loop. This deliberately does not take control of
    the player's camera yet; it publishes the latest native sample so missions
    and the future camera bridge can consume it safely.
*/
A3VRHybrid_tracking = [];
private _swapWasDown = false;
private _postureStickDirection = 0;
private _postureLevel = -1;
private _lastPostureRequest = -10;
private _roomscaleCrouchWasActive = false;
private _roomscaleOwnsCrouch = false;
private _trackedPlayer = objNull;
missionNamespace setVariable ["A3VRHybrid_radialOpen", false, false];

private _selectNativeWeapon = {
    params ["_weapon"];
    if (_weapon isEqualTo "") exitWith {};
    private _muzzles = getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
    private _muzzle = _weapon;
    if (count _muzzles > 0 && {(_muzzles # 0) isNotEqualTo "this"}) then {
        _muzzle = _muzzles # 0;
    };
    player selectWeapon _muzzle;
};

private _stanceLevelFor = {
    params ["_unit"];
    switch (stance _unit) do {
        case "CROUCH": {1};
        case "PRONE": {2};
        default {0};
    };
};

private _applyStanceLevel = {
    params ["_unit", "_level"];
    private _actions = ["PlayerStand", "PlayerCrouch", "PlayerProne"];
    private _safeLevel = (_level max 0) min 2;
    _unit playActionNow (_actions # _safeLevel);
};

while {true} do {
    private _raw = "A3VRHybridCore" callExtension "pose";
    private _sample = parseSimpleArray _raw;
    if (_sample isEqualType [] && {count _sample >= 7}) then {
        A3VRHybrid_tracking = _sample;
        missionNamespace setVariable ["A3VRHybrid_tracking", _sample, false];

        if (count _sample > 8 && {!isNull player} && {alive player}) then {
            private _controller = _sample # 8;
            if (_controller isEqualType [] && {count _controller >= 5}) then {
                private _buttons = round (_controller # 2);
                if (!(_trackedPlayer isEqualTo player)) then {
                    _trackedPlayer = player;
                    _postureLevel = [player] call _stanceLevelFor;
                    _postureStickDirection = 0;
                    _roomscaleCrouchWasActive = false;
                    _roomscaleOwnsCrouch = false;
                };
                // Avoid the newer bitAnd command here: older Arma parsers load
                // the function before accepting it and abort the entire loop.
                private _swapDown = (((floor (_buttons / 32)) mod 2) isEqualTo 1);
                private _onFoot = vehicle player isEqualTo player;
                // Do not use `dialog`: Action Menu/CBA can keep invisible
                // helper dialogs alive and used to disable weapon switching.
                private _gameplayInput = _onFoot && {!visibleMap} &&
                    {isNull (findDisplay 49)} &&
                    {isNull (findDisplay 160)} &&
                    {isNull (findDisplay 312)} &&
                    {isNull (findDisplay 602)};

                // Left Y/B cycles actual equipped weapons. This includes modded
                // primary, handgun and launcher classes without hardcoding.
                if (_gameplayInput && {_swapDown} && {!_swapWasDown}) then {
                    private _primary = primaryWeapon player;
                    private _handgun = handgunWeapon player;
                    private _launcher = secondaryWeapon player;
                    private _weapons = [_primary, _handgun, _launcher];
                    _weapons = _weapons select {_x isNotEqualTo ""};
                    if (count _weapons > 0) then {
                        private _current = _weapons findIf {
                            (currentWeapon player) isEqualTo _x
                        };
                        private _next = if (_current < 0) then {0} else {
                            (_current + 1) mod (count _weapons)
                        };
                        [_weapons # _next] call _selectNativeWeapon;
                    };
                };
                _swapWasDown = _swapDown;

                // Each full right-stick flick changes exactly one requested
                // stance level. Keep a requested level instead of immediately
                // reading `stance player`: the animation can still report the
                // previous stance when two deliberate flicks happen quickly.
                private _vertical = _controller # 4;
                private _direction = if (_vertical > 0.65) then {1} else {
                    if (_vertical < -0.65) then {-1} else {0}
                };
                if (_gameplayInput && {_direction isNotEqualTo 0} &&
                    {_postureStickDirection isEqualTo 0}) then {
                    if (_postureLevel < 0) then {
                        _postureLevel = [player] call _stanceLevelFor;
                    };
                    private _step = if (_direction > 0) then {-1} else {1};
                    private _nextLevel = ((_postureLevel + _step) max 0) min 2;
                    if (_nextLevel isNotEqualTo _postureLevel) then {
                        _postureLevel = _nextLevel;
                        [player, _postureLevel] call _applyStanceLevel;
                        _lastPostureRequest = diag_tickTime;
                        // A manual stance request becomes authoritative until
                        // the next physical crouch transition.
                        _roomscaleOwnsCrouch = false;
                    };
                };
                _postureStickDirection = _direction;

                // Once the requested animation has settled, resynchronise with
                // Arma in case a mission, injury or vehicle changed the stance.
                if (_gameplayInput && {_direction isEqualTo 0} &&
                    {diag_tickTime - _lastPostureRequest > 0.70}) then {
                    _postureLevel = [player] call _stanceLevelFor;
                };

                // Bit 1024 is generated by the native runtime from HMD height.
                // A 30 cm drop after F8 requests crouch; rising above the 18 cm
                // hysteresis threshold stands again only when room scale was
                // responsible for the crouch. Manual crouch/prone is preserved.
                private _roomscaleCrouch =
                    (((floor (_buttons / 1024)) mod 2) isEqualTo 1);
                if (_gameplayInput && {_roomscaleCrouch} &&
                    {!_roomscaleCrouchWasActive} && {_postureLevel isEqualTo 0} &&
                    {diag_tickTime - _lastPostureRequest > 0.18}) then {
                    _postureLevel = 1;
                    [player, _postureLevel] call _applyStanceLevel;
                    _lastPostureRequest = diag_tickTime;
                    _roomscaleOwnsCrouch = true;
                };
                if (_gameplayInput && {!_roomscaleCrouch} &&
                    {_roomscaleCrouchWasActive} && {_roomscaleOwnsCrouch} &&
                    {_postureLevel isEqualTo 1}) then {
                    _postureLevel = 0;
                    [player, _postureLevel] call _applyStanceLevel;
                    _lastPostureRequest = diag_tickTime;
                    _roomscaleOwnsCrouch = false;
                };
                _roomscaleCrouchWasActive = _roomscaleCrouch;
            };
        };
    };
    uiSleep 0.01;
};
