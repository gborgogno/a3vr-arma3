/*
    Native first-person weapon path with a local hands/forearms-only body.

    The Arma soldier remains authoritative for weapon model, attachments,
    optics, recoil, muzzle flash, smoke, projectiles and animation. Only body
    selections that should not appear inside the headset are hidden locally.
*/
if (!hasInterface) exitWith {};

A3VR_handsOnlyUnit = objNull;
A3VR_handsOnlyApplied = [];

A3VR_handsOnlyCandidates = [
    "head", "neck", "neck1",
    "spine", "spine1", "spine2", "spine3",
    "pelvis",
    "leftupleg", "leftuplegroll", "leftleg", "leftlegroll",
    "leftfoot", "lefttoebase",
    "rightupleg", "rightuplegroll", "rightleg", "rightlegroll",
    "rightfoot", "righttoebase",
    "injury_body", "injury_legs", "body_proxy", "head_proxy",
    "launcher", "nvg", "binoculars", "pistol_holstered",
    "insignia", "clan",
    "proxy:\a3\characters_f\proxies\head_male.001",
    "proxy:\a3\characters_f\proxies\headgear.001",
    "proxy:\a3\characters_f\proxies\glasses.001",
    "proxy:\a3\characters_f\proxies\hmd.001",
    "proxy:\a3\characters_f\proxies\nvg.001",
    "proxy:\a3\characters_f\proxies\equipment.001",
    "proxy:\a3\characters_f\proxies\backpack.001",
    "proxy:\a3\characters_f\proxies\backpack2.001",
    "proxy:\a3\characters_f\proxies\radio.001",
    "proxy:\a3\characters_f\proxies\flag.001",
    "proxy:\a3\characters_f\proxies\pistol_holstered.001"
];

A3VR_fnc_restoreHandsOnly = {
    if (!isNull A3VR_handsOnlyUnit) then {
        {
            A3VR_handsOnlyUnit hideSelection [_x, false];
        } forEach A3VR_handsOnlyApplied;
    };
    A3VR_handsOnlyUnit = objNull;
    A3VR_handsOnlyApplied = [];
};

A3VR_fnc_applyHandsOnly = {
    params ["_unit"];
    call A3VR_fnc_restoreHandsOnly;
    if (isNull _unit) exitWith {};

    private _available = selectionNames _unit;
    private _availableLower = _available apply {toLower _x};
    private _hidden = [];
    {
        private _candidateLower = toLower _x;
        private _index = _availableLower find _candidateLower;
        if (_index >= 0) then {
            private _actual = _available # _index;
            _unit hideSelection [_actual, true];
            _hidden pushBack _actual;
        };
    } forEach A3VR_handsOnlyCandidates;

    A3VR_handsOnlyUnit = _unit;
    A3VR_handsOnlyApplied = _hidden;
    diag_log format [
        "[A3VR] Native hands-only active unit=%1 hidden=%2 weapon=%3 items=%4",
        typeOf _unit, _hidden, currentWeapon _unit, weaponsItems _unit
    ];
};

waitUntil {uiSleep 0.1; !isNull findDisplay 46};

addMissionEventHandler ["MPEnded", {call A3VR_fnc_restoreHandsOnly;}];
addMissionEventHandler ["Ended", {call A3VR_fnc_restoreHandsOnly;}];

while {true} do {
    private _shouldApply = !isNull player && {alive player} &&
        {vehicle player isEqualTo player} && {cameraView isEqualTo "INTERNAL"};

    if (_shouldApply) then {
        if (A3VR_handsOnlyUnit isNotEqualTo player) then {
            [player] call A3VR_fnc_applyHandsOnly;
        };
    } else {
        if (!isNull A3VR_handsOnlyUnit) then {
            call A3VR_fnc_restoreHandsOnly;
        };
    };
    uiSleep 0.1;
};
