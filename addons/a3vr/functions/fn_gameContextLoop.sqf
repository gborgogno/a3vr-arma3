/*
    Publishes reliable Arma UI, Zeus and vehicle context to the native runtime.
    Windows cursor visibility alone is not reliable for every Arma display.
*/
if (!hasInterface) exitWith {};

disableSerialization;
private _lastContext = "";
private _cursor = controlNull;
private _cursorDisplay = displayNull;

while {true} do {
    private _zeus = !isNull (findDisplay 312);
    private _vehicle = !isNull player && {vehicle player isNotEqualTo player};
    // Do not use every entry from allDisplays here. ACE/CBA and other mods can
    // keep invisible helper displays alive throughout gameplay, which used to
    // lock A3VR in cursor mode and remove weapon motion. Only genuine Arma
    // screens and the explicitly tracked Action Menu are cursor contexts.
    private _knownUiDisplays = [
        findDisplay 49,   // Pause
        findDisplay 160,  // UAV terminal
        findDisplay 312,  // Zeus
        findDisplay 602   // Inventory
    ] select {!isNull _x};
    private _map = visibleMap;
    // Display 12 may stay allocated after the map closes, so visibility—not
    // mere existence—is authoritative. Display 46 exists only in a mission.
    private _mainMenu = isNull (findDisplay 46);
    private _ui = _mainMenu || {_map} || {count _knownUiDisplays > 0};

    private _parts = [];
    if (_ui) then {_parts pushBack "ui";};
    if (_zeus) then {_parts pushBack "zeus";};
    if (_vehicle) then {_parts pushBack "vehicle";};
    private _context = _parts joinString ",";
    if (_context isNotEqualTo _lastContext) then {
        "A3VRHybridCore" callExtension ("context:" + _context);
        _lastContext = _context;
    };

    private _targetDisplay = displayNull;
    if (_mainMenu) then {
        _targetDisplay = findDisplay 0;
        if (isNull _targetDisplay) then {
            private _menuDisplays = allDisplays select {!isNull _x};
            if (count _menuDisplays > 0) then {
                _targetDisplay = _menuDisplays # ((count _menuDisplays) - 1);
            };
        };
    };
    if (count _knownUiDisplays > 0) then {
        _targetDisplay = _knownUiDisplays # ((count _knownUiDisplays) - 1);
    };
    if (_map && {!isNull (findDisplay 12)}) then {
        _targetDisplay = findDisplay 12;
    };
    if (_zeus) then {_targetDisplay = findDisplay 312;};
    if (_ui && {!isNull _targetDisplay}) then {
        if (isNull _cursor || {_cursorDisplay isNotEqualTo _targetDisplay}) then {
            if (!isNull _cursor) then {ctrlDelete _cursor;};
            _cursor = _targetDisplay ctrlCreate ["RscText", -1];
            _cursor ctrlSetText "";
            _cursor ctrlSetBackgroundColor [0.1, 0.85, 1, 0.92];
            _cursor ctrlEnable false;
            _cursorDisplay = _targetDisplay;
        };
        private _mouse = getMousePosition;
        // Draw our own high-contrast pointer because Arma's native Windows
        // cursor is not consistently present in the captured VR texture.
        private _size = 0.018 * safeZoneH;
        _cursor ctrlSetPosition [
            (_mouse # 0) - (_size * 0.5),
            (_mouse # 1) - (_size * 0.5),
            _size,
            _size
        ];
        _cursor ctrlCommit 0;
    } else {
        if (!isNull _cursor) then {ctrlDelete _cursor;};
        _cursor = controlNull;
        _cursorDisplay = displayNull;
    };
    uiSleep 0.016;
};
