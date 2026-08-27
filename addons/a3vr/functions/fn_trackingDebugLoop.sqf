/* Menu-controlled tracking panel. No floating controller geometry is drawn. */
if (!hasInterface) exitWith {};
disableSerialization;

if (!isNil "A3VRHybrid_trackingDebugDrawEH") then {
    removeMissionEventHandler ["Draw3D", A3VRHybrid_trackingDebugDrawEH];
    A3VRHybrid_trackingDebugDrawEH = nil;
};

private _panel = controlNull;
private _panelDisplay = displayNull;

while {true} do {
    private _enabled = missionNamespace getVariable [
        "A3VRHybrid_debugEnabled", false];
    if (!_enabled) then {
        if (!isNull _panel) then {ctrlDelete _panel;};
        _panel = controlNull;
        _panelDisplay = displayNull;
    } else {
        private _targetDisplay = findDisplay 46;
        if (isNull _targetDisplay) then {
            private _displays = allDisplays select {!isNull _x};
            if (count _displays > 0) then {
                _targetDisplay = _displays # ((count _displays) - 1);
            };
        };
        if (!isNull _targetDisplay && {
            isNull _panel || {_panelDisplay isNotEqualTo _targetDisplay}}) then {
            if (!isNull _panel) then {ctrlDelete _panel;};
            _panel = _targetDisplay ctrlCreate ["RscStructuredText", -1];
            _panel ctrlSetPosition [
                safeZoneX + 0.012 * safeZoneW,
                safeZoneY + 0.075 * safeZoneH,
                0.31 * safeZoneW,
                0.19 * safeZoneH
            ];
            _panel ctrlSetBackgroundColor [0.01, 0.02, 0.03, 0.86];
            _panel ctrlCommit 0;
            _panelDisplay = _targetDisplay;
        };

        if (!isNull _panel) then {
            private _sample = missionNamespace getVariable [
                "A3VRHybrid_tracking", []];
            private _isTracked = {
                params ["_index"];
                count _sample > _index && {
                    private _pose = _sample # _index;
                    _pose isEqualType [] && {count _pose >= 2} &&
                    {(_pose # 0) > 0} && {(_pose # 1) > 0}
                }
            };
            private _headOk = [4] call _isTracked;
            private _leftOk = [5] call _isTracked;
            private _rightOk = [6] call _isTracked;
            private _controller = if (count _sample > 8) then {
                _sample # 8
            } else {[0, 0, 0, 0, 0]};
            private _buttons = if (count _controller > 2) then {
                round (_controller # 2)
            } else {0};
            private _settings = "A3VRHybridCore" callExtension "settings";
            private _statusColor = {
                params ["_ok"];
                ["#FF6B6B", "#62FF91"] select _ok
            };
            private _text = format [
                "<t size='1.10' color='#38DFFF'>A3VR TRACKING DIAGNOSTIC</t><br/>" +
                "HMD: <t color='%1'>%2</t>   LEFT: <t color='%3'>%4</t>   RIGHT: <t color='%5'>%6</t><br/>" +
                "Move: %7 / %8   Turn: %9 / %10   Buttons: %11<br/>" +
                "<t size='0.82' color='#B8C7D1'>%12</t>",
                [_headOk] call _statusColor,
                ["LOST", "TRACKED"] select _headOk,
                [_leftOk] call _statusColor,
                ["LOST", "TRACKED"] select _leftOk,
                [_rightOk] call _statusColor,
                ["LOST", "TRACKED"] select _rightOk,
                if (count _controller > 0) then {_controller # 0} else {0},
                if (count _controller > 1) then {_controller # 1} else {0},
                if (count _controller > 3) then {_controller # 3} else {0},
                if (count _controller > 4) then {_controller # 4} else {0},
                _buttons, _settings
            ];
            _panel ctrlSetStructuredText parseText _text;
        };
    };
    uiSleep 0.10;
};
