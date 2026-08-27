/* Add an A3VR entry to Arma's pause, map and inventory displays. All former
   F5-F10 handlers are intentionally retired to avoid native key conflicts. */
if (!hasInterface) exitWith {};
disableSerialization;

while {true} do {
    {
        if (!isNull _x && {isNull (_x getVariable [
            "A3VRHybrid_settingsButton", controlNull])}) then {
            private _button = _x ctrlCreate ["RscButton", -1];
            _button ctrlSetPosition [
                safeZoneX + safeZoneW - 0.185 * safeZoneW,
                safeZoneY + 0.035 * safeZoneH,
                0.155 * safeZoneW, 0.045 * safeZoneH];
            _button ctrlSetText "A3VR VR SETTINGS";
            _button ctrlSetTextColor [0.92, 0.99, 1, 1];
            _button ctrlSetBackgroundColor [0.02, 0.48, 0.61, 0.96];
            _button ctrlSetTooltip "Open controller, comfort and weapon settings";
            _button buttonSetAction "call A3VRHybrid_fnc_openSettingsMenu";
            _button ctrlCommit 0;
            _x setVariable ["A3VRHybrid_settingsButton", _button];
        };
    } forEach [findDisplay 49, findDisplay 12, findDisplay 602];
    uiSleep 0.20;
};
