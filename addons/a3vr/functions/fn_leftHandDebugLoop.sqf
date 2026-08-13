/*
    Local-only tracked-hand calibration view. F7 toggles it without touching
    the native weapon, camera or controller mappings.
*/
if (!hasInterface) exitWith {};

A3VRHybrid_leftHandVisible = true;

if (!isNil "A3VRHybrid_leftHandDrawEH") then {
    removeMissionEventHandler ["Draw3D", A3VRHybrid_leftHandDrawEH];
};
A3VRHybrid_leftHandDrawEH = addMissionEventHandler ["Draw3D", {
    if (missionNamespace getVariable ["A3VRHybrid_leftHandVisible", true]) then {
        call A3VRHybrid_fnc_drawLeftHand;
    };
}];

waitUntil {uiSleep 0.1; !isNull findDisplay 46};
private _display = findDisplay 46;

if (!isNil "A3VRHybrid_leftHandKeyEH") then {
    _display displayRemoveEventHandler ["KeyDown", A3VRHybrid_leftHandKeyEH];
};
A3VRHybrid_leftHandKeyEH = _display displayAddEventHandler ["KeyDown", {
    params ["_display", "_key"];
    if (_key isEqualTo 65) exitWith {
        private _visible = !(missionNamespace getVariable ["A3VRHybrid_leftHandVisible", true]);
        missionNamespace setVariable ["A3VRHybrid_leftHandVisible", _visible, false];
        systemChat format ["A3VR left hand: %1", ["off", "on"] select _visible];
        true
    };
    false
}];

diag_log "[A3VR] Left-hand calibration renderer active (F7 toggles visibility)";
