/*
    Publishes explicit Arma UI/Zeus/vehicle context to the native runtime and
    draws a capture-safe mouse cursor and dotted guide ray. The runtime defaults to UI
    framing before this loop starts, so logos and loading screens are never
    cropped. UI context enables the pointer automatically and gameplay hides it.
*/
if (!hasInterface) exitWith {};

disableSerialization;
private _lastContext = "__unset__";
private _lastContextPublish = -10;
private _contextPlayer = objNull;
private _briefingMapSeen = false;

private _ensureCursor = {
    params ["_display"];
    if (isNull _display) exitWith {[]};
    private _controls = _display getVariable [
        "A3VRHybrid_cursorControls", []];
    if (count _controls isEqualTo 14) exitWith {_controls};

    {
        if (!isNull _x) then {ctrlDelete _x;};
    } forEach _controls;
    _controls = [];
    for "_index" from 0 to 1 do {
        private _control = _display ctrlCreate ["RscPicture", -1];
        _control ctrlSetText "\a3\ui_f\data\gui\cfg\cursors\arrow_gs.paa";
        _control ctrlSetTextColor (
            if (_index isEqualTo 0) then {[0, 0, 0, 0.92]}
            else {[1, 1, 1, 1]}
        );
        _control ctrlEnable false;
        _controls pushBack _control;
    };
    for "_index" from 0 to 11 do {
        private _dot = _display ctrlCreate ["RscPicture", -1];
        _dot ctrlSetText "\a3\ui_f\data\map\markers\military\dot_ca.paa";
        _dot ctrlSetTextColor [0.16, 0.82, 1.0, 0.26 + 0.055 * _index];
        _dot ctrlEnable false;
        _controls pushBack _dot;
    };
    _display setVariable ["A3VRHybrid_cursorControls", _controls];
    _controls
};

private _positionCursor = {
    params ["_controls", "_mouse", "_visible"];
    if (count _controls isNotEqualTo 14) exitWith {};
    private _size = 0.036 * safeZoneH;
    private _x = _mouse # 0;
    private _y = _mouse # 1;
    for "_layer" from 0 to 1 do {
        private _control = _controls # _layer;
        private _offset = if (_layer isEqualTo 0) then {
            0.0022 * safeZoneH
        } else {0};
        _control ctrlSetPosition [
            _x + _offset,
            _y + _offset,
            _size,
            _size
        ];
        _control ctrlCommit 0;
        _control ctrlShow _visible;
    };
    private _anchorX = safeZoneX + 0.50 * safeZoneW;
    private _anchorY = safeZoneY + 0.92 * safeZoneH;
    private _dotSize = 0.0095 * safeZoneH;
    for "_index" from 0 to 11 do {
        private _t = (_index + 1) / 13;
        private _dot = _controls # (_index + 2);
        _dot ctrlSetPosition [
            _anchorX + ((_x - _anchorX) * _t) - (_dotSize * 0.5),
            _anchorY + ((_y - _anchorY) * _t) - (_dotSize * 0.5),
            _dotSize, _dotSize];
        _dot ctrlCommit 0;
        _dot ctrlShow _visible;
    };
};

while {true} do {
    private _zeus = !isNull (findDisplay 312);
    // Display 313 remains allocated behind an Eden mission preview. is3DEN
    // and is3DENPreview describe the active state instead of that stale
    // display handle, so gameplay framing can be restored immediately.
    private _edenPreview = is3DENPreview;
    private _eden = is3DEN && {!_edenPreview};
    private _vehicle = !isNull player && {vehicle player isNotEqualTo player};
    private _map = visibleMap;
    if (!(_contextPlayer isEqualTo player)) then {
        _contextPlayer = player;
        _briefingMapSeen = false;
    };
    if (_map && {!isNull player}) then {
        _briefingMapSeen = true;
    };
    private _commandMenu = commandingMenu isNotEqualTo "";
    private _rawDialog = dialog;
    private _settingsOpen = !isNull (uiNamespace getVariable [
        "A3VRHybrid_settingsDisplay", displayNull]);
    private _pauseMenu = !isNull (findDisplay 49);
    private _rootDisplay = findDisplay 46;
    private _knownDisplays = [
        _rootDisplay,
        findDisplay 12,   // Map
        findDisplay 49,   // Pause
        findDisplay 70, findDisplay 101, findDisplay 103, // Loading
        findDisplay 160,  // UAV terminal
        findDisplay 312,  // Zeus
        findDisplay 313,  // Eden
        findDisplay 602,  // Inventory
        uiNamespace getVariable [
            "A3VRHybrid_settingsDisplay", displayNull]
    ] select {!isNull _x};
    // DLCs and third-party addons use their own IDDs. Record a focused custom
    // display here, then distinguish an input-owning dialog from a HUD below.
    // A display/HUD may keep focus without blocking gameplay, which is exactly
    // what Spearhead's campaign overlay does after its briefing ends.
    private _focusedCustomUi = false;
    {
        if (!isNull _x && {!(_x in _knownDisplays)}) then {
            private _focus = focusedCtrl _x;
            if (!isNull _focus && {ctrlShown _focus}) then {
                _focusedCustomUi = true;
            };
        };
        if (_focusedCustomUi) exitWith {};
    } forEach allDisplays;
    private _proxyCamera = missionNamespace getVariable [
        "A3VRHybrid_proxyCamera", objNull];
    private _directGameplayCamera = !isNull player && {!isNull cameraOn} && {
        cameraOn isEqualTo vehicle player ||
        {!isNull _proxyCamera && {cameraOn isEqualTo _proxyCamera}}
    };
    // The proxy owns a real Arma camera during gameplay. Treating that camera
    // as a cutscene left Spearhead permanently in UI framing after cinematics.
    private _cutscene = !isNull player && {!isNull cameraOn} && {
        !_directGameplayCamera
    };
    // `dialog` is global state, not proof that a visible foreground menu still
    // owns input. Campaign frameworks can leave it true after returning the
    // real player camera. Visible custom dialogs are classified below through
    // their focused control; raw dialog state only blocks a non-gameplay
    // camera such as a briefing or cinematic.
    private _genericDialog = _rawDialog && {!_directGameplayCamera};

    // Keep this list explicit: ACE/CBA can leave invisible helper displays
    // alive during gameplay. Those helpers must not disable native weapon aim.
    private _blockingUiDisplays = [
        findDisplay 49,   // Pause
        findDisplay 160,  // UAV terminal
        findDisplay 312,  // Zeus
        findDisplay 602   // Inventory
    ] select {!isNull _x};
    if (_eden) then {_blockingUiDisplays pushBack (findDisplay 313);};
    // Campaigns may keep loading display handles allocated after returning
    // control. They remain UI only until the direct gameplay camera returns.
    private _loadingDisplays = [
        findDisplay 70, findDisplay 101, findDisplay 103
    ] select {!isNull _x};
    // Some campaigns retain a loading display object for the whole mission.
    // It is active UI only while the gameplay camera has not returned; the
    // retained handle must not keep stereo/proxy mode disabled indefinitely.
    private _loadingUiActive = count _loadingDisplays > 0 && {
        !_directGameplayCamera
    };
    // Dialogs own input; ordinary displays/HUDs do not. Keep a campaign's
    // pre-game overlay in UI mode until its briefing map has appeared, then
    // ignore the focused HUD that Spearhead retains during live gameplay.
    private _campaignBriefingUi = _focusedCustomUi && {
        count _loadingDisplays > 0
    } && {!_briefingMapSeen};
    private _customUi = _focusedCustomUi && {
        _rawDialog || {_campaignBriefingUi}
    };

    private _gameplay = !isNull player && {alive player} &&
        {!isNull (findDisplay 46)} && {_directGameplayCamera} &&
        {!_map} && {!_cutscene} && {!_settingsOpen} && {!_zeus} &&
        {!_eden} && {!_commandMenu} && {!_genericDialog} && {!_customUi} &&
        {count _blockingUiDisplays isEqualTo 0};
    // Eden preview is authoritative gameplay even though its editor display
    // can still be found in the background.
    if (_edenPreview && {!_map} && {!_settingsOpen} && {!_zeus}) then {
        _gameplay = true;
    };
    private _mainMenuOrLoading = isNull (findDisplay 46) && {!_gameplay};
    private _ui = !_gameplay && {
        _mainMenuOrLoading || {_map} || {_cutscene} || {_settingsOpen} ||
        {_commandMenu} || {_genericDialog} || {_customUi} ||
        {count _blockingUiDisplays > 0} || {_loadingUiActive}
    };
    // Main/Start, pause, addon/configuration displays and Zeus belong to the
    // physical mouse. Map and inventory retain the configured VR pointer so
    // their controller chords can close those displays again.
    private _mouseUi = _ui && {
        _mainMenuOrLoading || {_pauseMenu} || {_settingsOpen} ||
        {_zeus} || {_eden} || {_customUi}
    };
    missionNamespace setVariable [
        "A3VRHybrid_contextGameplay", _gameplay, false];
    missionNamespace setVariable ["A3VRHybrid_contextUi", _ui, false];
    private _parts = [];
    if (_ui) then {_parts pushBack "ui";};
    if (_zeus || {_eden}) then {_parts pushBack "zeus";};
    if (_mouseUi) then {_parts pushBack "mouse";};
    if (_vehicle) then {_parts pushBack "vehicle";};
    if (_gameplay) then {_parts pushBack "gameplay";};
    private _context = _parts joinString ",";
    if (_context isNotEqualTo _lastContext ||
        {diag_tickTime - _lastContextPublish >= 0.50}) then {
        "A3VRHybridCore" callExtension ("context:" + _context);
        if (_context isNotEqualTo _lastContext) then {
            diag_log format [
                "[A3VR] Context transition=%1 gameplay=%2 ui=%3 camera=%4 proxyCamera=%5 loadingDisplays=%6 loadingActive=%7 dialog=%8 custom=%9 focusedCustom=%10 briefingMapSeen=%11 direct=%12 map=%13 blocking=%14",
                _context, _gameplay, _ui, str cameraOn,
                str _proxyCamera, count _loadingDisplays, _loadingUiActive,
                _rawDialog, _customUi, _focusedCustomUi, _briefingMapSeen,
                _directGameplayCamera, _map, count _blockingUiDisplays
            ];
        };
        _lastContext = _context;
        _lastContextPublish = diag_tickTime;
    };

    // The core composites the real Windows cursor and its guide directly into
    // the VR capture texture. SQF controls cannot cover the pre-mission main
    // menu and could otherwise draw a second cursor over in-mission dialogs.

    uiSleep 0.016;
};
