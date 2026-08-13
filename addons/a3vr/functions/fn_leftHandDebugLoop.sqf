/*
    Local-only tracked-hand calibration view. F7 toggles it without touching
    the native weapon, camera or controller mappings.
*/
if (!hasInterface) exitWith {};

A3VR_leftHandVisible = true;

if (!isNil "A3VR_leftHandDrawEH") then {
    removeMissionEventHandler ["Draw3D", A3VR_leftHandDrawEH];
};
A3VR_leftHandDrawEH = addMissionEventHandler ["Draw3D", {
    if (missionNamespace getVariable ["A3VR_leftHandVisible", true]) then {
        call A3VR_fnc_drawLeftHand;
    };
}];

waitUntil {uiSleep 0.1; !isNull findDisplay 46};
private _display = findDisplay 46;

if (!isNil "A3VR_leftHandKeyEH") then {
    _display displayRemoveEventHandler ["KeyDown", A3VR_leftHandKeyEH];
};
A3VR_leftHandKeyEH = _display displayAddEventHandler ["KeyDown", {
    params ["_display", "_key"];
    if (_key isEqualTo 65) exitWith {
        private _visible = !(missionNamespace getVariable ["A3VR_leftHandVisible", true]);
        missionNamespace setVariable ["A3VR_leftHandVisible", _visible, false];
        systemChat format ["A3VR left hand: %1", ["off", "on"] select _visible];
        true
    };
    false
}];

diag_log "[A3VR] Left-hand calibration renderer active (F7 toggles visibility)";
