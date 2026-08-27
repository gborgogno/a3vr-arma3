/* Open/close the controller-first A3VR configuration display. */
if (!hasInterface) exitWith {};
disableSerialization;

private _existing = uiNamespace getVariable ["A3VRHybrid_settingsDisplay", displayNull];
if (!isNull _existing) exitWith {_existing closeDisplay 2;};
private _parent = findDisplay 46;
if (isNull _parent) then {
    private _displays = allDisplays select {!isNull _x};
    if (count _displays > 0) then {_parent = _displays # ((count _displays) - 1);};
};
if (isNull _parent) exitWith {systemChat "A3VR: no active display for settings.";};
private _display = _parent createDisplay "RscDisplayEmpty";
if (isNull _display) exitWith {systemChat "A3VR: settings display could not be created.";};
uiNamespace setVariable ["A3VRHybrid_settingsDisplay", _display];
_display displayAddEventHandler ["Unload", {
    uiNamespace setVariable ["A3VRHybrid_settingsDisplay", displayNull];
}];
_display displayAddEventHandler ["KeyDown", {
    params ["_display", "_key"];
    if (_key isEqualTo 1) exitWith {_display closeDisplay 2; true};
    false
}];

private _panelX = safeZoneX + 0.21 * safeZoneW;
private _panelY = safeZoneY + 0.055 * safeZoneH;
private _w = 0.58 * safeZoneW;
private _h = 0.89 * safeZoneH;
private _rowH = 0.045 * safeZoneH;

private _shadow = _display ctrlCreate ["RscText", 7298];
_shadow ctrlSetPosition [_panelX + 0.007 * safeZoneW, _panelY + 0.010 * safeZoneH, _w, _h];
_shadow ctrlSetBackgroundColor [0, 0, 0, 0.58];
_shadow ctrlCommit 0;
private _background = _display ctrlCreate ["RscText", 7300];
_background ctrlSetPosition [_panelX, _panelY, _w, _h];
_background ctrlSetBackgroundColor [0.010, 0.019, 0.028, 0.985];
_background ctrlCommit 0;
private _accent = _display ctrlCreate ["RscText", 7299];
_accent ctrlSetPosition [_panelX, _panelY, 0.007 * safeZoneW, _h];
_accent ctrlSetBackgroundColor [0.04, 0.72, 0.88, 1];
_accent ctrlCommit 0;

private _title = _display ctrlCreate ["RscStructuredText", 7301];
_title ctrlSetPosition [_panelX + 0.025 * safeZoneW, _panelY + 0.018 * safeZoneH, 0.45 * safeZoneW, 0.074 * safeZoneH];
_title ctrlSetStructuredText parseText (
    "<t size='1.38' font='RobotoCondensedBold' color='#EAFBFF'>A3VR HYBRID</t><br/>" +
    "<t size='0.82' color='#73DDF2'>Controller-first VR settings</t>");
_title ctrlCommit 0;
private _closeTop = _display ctrlCreate ["RscButton", 7302];
_closeTop ctrlSetPosition [_panelX + 0.515 * safeZoneW, _panelY + 0.023 * safeZoneH, 0.040 * safeZoneW, 0.046 * safeZoneH];
_closeTop ctrlSetText "X";
_closeTop ctrlSetTextColor [0.86, 0.95, 0.98, 1];
_closeTop ctrlSetBackgroundColor [0.08, 0.13, 0.17, 1];
_closeTop buttonSetAction "(uiNamespace getVariable ['A3VRHybrid_settingsDisplay', displayNull]) closeDisplay 2";
_closeTop ctrlCommit 0;
private _section = _display ctrlCreate ["RscText", 7303];
_section ctrlSetPosition [_panelX + 0.025 * safeZoneW, _panelY + 0.095 * safeZoneH, 0.53 * safeZoneW, 0.032 * safeZoneH];
_section ctrlSetText "GAMEPLAY & COMFORT";
_section ctrlSetTextColor [0.35, 0.82, 0.94, 1];
_section ctrlSetBackgroundColor [0.025, 0.070, 0.095, 0.92];
_section ctrlCommit 0;

private _rows = [
    ["Gameplay aim", "aim", 7310, 7311],
    ["Menu pointer", "pointer", 7312, 7313],
    ["Smooth turning", "turn", 7314, 7315],
    ["2D UI scale", "ui", 7316, 7317],
    ["Tracking diagnostic", "debug", 7318, 7319],
    ["Movement direction", "movement", 7320, 7324],
    ["Native ADS on right grip", "optic", 7325, 7326],
    ["Proxy HUD / mission markers", "hud", 7333, 7334],
    ["Weapon recoil", "recoil", 7329, 7330],
    ["Weapon control", "weapon", 7331, 7332],
    ["Motion aiming", "motion", 7335, 7336]
];
{
    _x params ["_labelText", "_setting", "_labelId", "_buttonId"];
    private _rowY = _panelY + 0.132 * safeZoneH + _forEachIndex * _rowH;
    private _row = _display ctrlCreate ["RscText", 7400 + _forEachIndex];
    _row ctrlSetPosition [_panelX + 0.025 * safeZoneW, _rowY, 0.53 * safeZoneW, 0.040 * safeZoneH];
    _row ctrlSetBackgroundColor (if ((_forEachIndex mod 2) isEqualTo 0) then {
        [0.030, 0.052, 0.068, 0.90]
    } else {[0.020, 0.038, 0.052, 0.90]});
    _row ctrlCommit 0;
    private _label = _display ctrlCreate ["RscText", _labelId];
    _label ctrlSetPosition [_panelX + 0.040 * safeZoneW, _rowY, 0.275 * safeZoneW, 0.040 * safeZoneH];
    _label ctrlSetText _labelText;
    _label ctrlSetTextColor [0.84, 0.90, 0.94, 1];
    _label ctrlCommit 0;
    private _button = _display ctrlCreate ["RscButton", _buttonId];
    _button ctrlSetPosition [_panelX + 0.325 * safeZoneW, _rowY + 0.003 * safeZoneH, 0.215 * safeZoneW, 0.034 * safeZoneH];
    _button ctrlSetTextColor [0.91, 0.99, 1, 1];
    _button ctrlSetBackgroundColor [0.035, 0.39, 0.49, 0.96];
    _button ctrlSetTooltip "Click with the physical mouse to change";
    _button buttonSetAction format ["['%1'] call A3VRHybrid_fnc_cycleSetting", _setting];
    _button ctrlCommit 0;
} forEach _rows;

private _actionsY = _panelY + 0.645 * safeZoneH;
private _recenter = _display ctrlCreate ["RscButton", 7321];
_recenter ctrlSetPosition [_panelX + 0.025 * safeZoneW, _actionsY, 0.255 * safeZoneW, 0.052 * safeZoneH];
_recenter ctrlSetText "RECENTER HMD + AIM";
_recenter ctrlSetBackgroundColor [0.05, 0.55, 0.68, 1];
_recenter buttonSetAction "'A3VRHybridCore' callExtension 'recenter'; A3VRHybrid_proxyCalibrated = false; systemChat 'A3VR recentered.'";
_recenter ctrlCommit 0;
private _close = _display ctrlCreate ["RscButton", 7322];
_close ctrlSetPosition [_panelX + 0.300 * safeZoneW, _actionsY, 0.255 * safeZoneW, 0.052 * safeZoneH];
_close ctrlSetText "RETURN TO GAME";
_close ctrlSetBackgroundColor [0.10, 0.15, 0.19, 1];
_close buttonSetAction "(uiNamespace getVariable ['A3VRHybrid_settingsDisplay', displayNull]) closeDisplay 2";
_close ctrlCommit 0;
private _help = _display ctrlCreate ["RscStructuredText", 7323];
_help ctrlSetPosition [_panelX + 0.025 * safeZoneW, _panelY + 0.720 * safeZoneH, 0.53 * safeZoneW, 0.135 * safeZoneH];
_help ctrlSetBackgroundColor [0.018, 0.031, 0.043, 0.96];
_help ctrlSetStructuredText parseText (
    "<t color='#73DDF2' font='RobotoCondensedBold'>VR SHORTCUTS</t><br/>" +
    "<t color='#DCECF1'>Hold left grip</t> settings  |  " +
    "<t color='#DCECF1'>Grip + B</t> proxy/native  |  " +
    "<t color='#DCECF1'>Grip + X</t> map  |  " +
    "<t color='#DCECF1'>Grip + Y</t> inventory<br/>" +
    "Configuration and Zeus use the physical mouse. Map and inventory can use the VR cursor and guide ray. " +
    "F-key shortcuts were removed to avoid native Arma conflicts.");
_help ctrlCommit 0;
call A3VRHybrid_fnc_refreshSettingsMenu;
