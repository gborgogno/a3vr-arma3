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
private _aimFeedbackOnline = false;
private _menuGripWasDown = false;
private _menuGripStarted = -1;
private _menuGripTriggered = false;
private _proxyToggleWasDown = false;
private _lastHeadBodyUpdate = diag_tickTime;
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

        // Close the native controller-aim loop with the direction of the
        // weapon that Arma is actually rendering and firing. The runtime uses
        // this feedback to correct missed/delayed input instead of accumulating
        // controller deltas forever. No proxy weapon or projectile is created.
        private _contextGameplay = missionNamespace getVariable [
            "A3VRHybrid_contextGameplay", false];
        private _contextUi = missionNamespace getVariable [
            "A3VRHybrid_contextUi", false];

        if (_contextGameplay && {!_contextUi} &&
            {!isNull player} && {alive player} &&
            {vehicle player isEqualTo player} &&
            {cameraView isEqualTo "INTERNAL"} && {!visibleMap}) then {
            private _feedbackWeapon = currentWeapon player;
            if (_feedbackWeapon isNotEqualTo "") then {
                private _feedbackDirection =
                    player weaponDirection _feedbackWeapon;
                private _feedbackCommand = format [
                    "aim_feedback:%1,%2,%3",
                    _feedbackDirection # 0,
                    _feedbackDirection # 1,
                    _feedbackDirection # 2
                ];
                private _feedbackStatus =
                    "A3VRHybridCore" callExtension _feedbackCommand;
                if (!_aimFeedbackOnline && {_feedbackStatus isEqualTo "ok"}) then {
                    _aimFeedbackOnline = true;
                    diag_log "[A3VR] Native weapon aim feedback online";
                };
            } else {
                "A3VRHybridCore" callExtension "aim_feedback:invalid";
            };
        } else {
            "A3VRHybridCore" callExtension "aim_feedback:invalid";
        };

        // Left grip is otherwise reserved in this alpha. Holding it opens or
        // closes the A3VR menu without requiring the keyboard.
        if (count _sample > 8) then {
            private _menuController = _sample # 8;
            if (_menuController isEqualType [] && {count _menuController >= 3}) then {
                private _menuButtons = round (_menuController # 2);
                private _menuGripDown =
                    (((floor (_menuButtons / 512)) mod 2) isEqualTo 1);
                private _menuChordDown =
                    (((floor (_menuButtons / 8)) mod 2) isEqualTo 1) ||
                    {((floor (_menuButtons / 16)) mod 2) isEqualTo 1} ||
                    {((floor (_menuButtons / 32)) mod 2) isEqualTo 1} ||
                    {((floor (_menuButtons / 64)) mod 2) isEqualTo 1} ||
                    {((floor (_menuButtons / 256)) mod 2) isEqualTo 1};
                private _proxyToggleDown = _menuGripDown &&
                    {((floor (_menuButtons / 256)) mod 2) isEqualTo 1};
                if (_menuGripDown && {!_menuGripWasDown}) then {
                    _menuGripStarted = diag_tickTime;
                    _menuGripTriggered = false;
                };
                // A quick grip+A, grip+right-stick-click or grip+B is a
                // weapon/control chord, not a request to open settings.
                // Keep the menu suppressed until the grip is released.
                if (_menuGripDown && {_menuChordDown}) then {
                    _menuGripTriggered = true;
                };
                if (_contextGameplay && {!_contextUi} &&
                    {_proxyToggleDown} && {!_proxyToggleWasDown} &&
                    {!(isNil "A3VRHybrid_fnc_toggleWeaponProxy")}) then {
                    call A3VRHybrid_fnc_toggleWeaponProxy;
                };
                if (_contextGameplay && {!_contextUi} &&
                    {_menuGripDown} && {!_menuGripTriggered} &&
                    {_menuGripStarted >= 0} &&
                    {diag_tickTime - _menuGripStarted >= 0.65}) then {
                    _menuGripTriggered = true;
                    call A3VRHybrid_fnc_openSettingsMenu;
                };
                if (!_menuGripDown) then {
                    _menuGripStarted = -1;
                    _menuGripTriggered = false;
                };
                _menuGripWasDown = _menuGripDown;
                _proxyToggleWasDown = _proxyToggleDown;
            };
        };

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
                private _modifierDown =
                    (((floor (_buttons / 512)) mod 2) isEqualTo 1);
                private _swapDown =
                    (((floor (_buttons / 32)) mod 2) isEqualTo 1) &&
                    {!_modifierDown};
                private _onFoot = vehicle player isEqualTo player;
                // Do not use `dialog`: Action Menu/CBA can keep invisible
                // helper dialogs alive and used to disable weapon switching.
                private _gameplayInput = _contextGameplay && {!_contextUi} &&
                    {_onFoot} && {!visibleMap} &&
                    {isNull (findDisplay 49)} &&
                    {isNull (findDisplay 160)} &&
                    {isNull (findDisplay 312)} &&
                    {isNull (findDisplay 602)};

                // Head-directed locomotion eases the actual local soldier
                // toward the rendered camera heading. Each small body step is
                // transferred into the FreeTrack origin so the world view
                // stays stable instead of flickering through setDir snaps.
                private _moveY = _controller # 1;
                private _headBodyNow = diag_tickTime;
                private _headBodyDelta =
                    ((_headBodyNow - _lastHeadBodyUpdate) max 0) min 0.05;
                _lastHeadBodyUpdate = _headBodyNow;
                private _headMovementMode =
                    (missionNamespace getVariable [
                        "A3VRHybrid_settingMovementDirection", "head"])
                    isEqualTo "head";
                private _headMoveActive = _gameplayInput &&
                    {_headMovementMode} && {abs _moveY > 0.35} &&
                    {!(missionNamespace getVariable [
                        "A3VRHybrid_proxyActive", false])};
                if (_headMoveActive && {_headBodyDelta > 0}) then {
                    private _viewDirection = getCameraViewDirection player;
                    private _horizontalLength = sqrt (
                        (_viewDirection # 0) * (_viewDirection # 0) +
                        (_viewDirection # 1) * (_viewDirection # 1));
                    if (_horizontalLength > 0.10) then {
                        private _targetHeading =
                            (_viewDirection # 0) atan2 (_viewDirection # 1);
                        _targetHeading = (_targetHeading + 360) % 360;
                        private _bodyHeading = getDir player;
                        private _headingError = (
                            _targetHeading - _bodyHeading + 540) % 360 - 180;
                        if (abs _headingError >= 0.75) then {
                            private _turnRate =
                                ((_headingError * 5) max -105) min 105;
                            private _bodyStep = _turnRate * _headBodyDelta;
                            if (abs _bodyStep > abs _headingError) then {
                                _bodyStep = _headingError;
                            };
                            player setDir (
                                (_bodyHeading + _bodyStep + 360) % 360);
                            "A3VRHybridCore" callExtension
                                ("body_yaw:" + str _bodyStep);
                        };
                    };
                };

                // Left Y/B cycles actual equipped weapons. This includes modded
                // primary, handgun and launcher classes without hardcoding.
                private _absoluteWeaponOwnsInput = missionNamespace getVariable
                    ["A3VRHybrid_weaponVisualActive", false];
                if (_gameplayInput && {!_absoluteWeaponOwnsInput} &&
                    {_swapDown} && {!_swapWasDown}) then {
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
                // A 30 cm drop after menu recenter requests crouch; rising above the 18 cm
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
