/* Apply and persist user-facing A3VR runtime options. */
if (!hasInterface) exitWith {};

private _aim = missionNamespace getVariable [
    "A3VRHybrid_settingAimSource", "right"];
private _pointer = missionNamespace getVariable [
    "A3VRHybrid_settingPointerSource", "head"];
private _turn = missionNamespace getVariable [
    "A3VRHybrid_settingTurnRate", "fast"];
private _uiSize = missionNamespace getVariable [
    "A3VRHybrid_settingUiSize", "full"];
private _movement = missionNamespace getVariable [
    "A3VRHybrid_settingMovementDirection", "head"];
private _opticFallback = missionNamespace getVariable [
    "A3VRHybrid_settingOpticFallback", "grip"];
private _proxyHud = missionNamespace getVariable [
    "A3VRHybrid_settingProxyHud", true];
private _recoil = missionNamespace getVariable [
    "A3VRHybrid_settingRecoil", "normal"];
private _motion = missionNamespace getVariable [
    "A3VRHybrid_proxyMotionEnabled", true];
private _debug = missionNamespace getVariable [
    "A3VRHybrid_debugEnabled", false];

if !(_aim in ["right", "left"]) then {_aim = "right";};
if !(_pointer in ["controller", "head"]) then {_pointer = "head";};
if !(_turn in ["comfort", "normal", "fast"]) then {_turn = "fast";};
if !(_uiSize in ["full", "large"]) then {_uiSize = "full";};
if !(_movement in ["body", "head"]) then {_movement = "head";};
if !(_opticFallback in ["grip", "off"]) then {_opticFallback = "grip";};
if !(_proxyHud isEqualType true) then {_proxyHud = true;};
if !(_recoil in ["off", "comfort", "normal"]) then {
    _recoil = "normal";
};
if !(_motion isEqualType true) then {_motion = true;};

missionNamespace setVariable ["A3VRHybrid_settingAimSource", _aim, false];
missionNamespace setVariable ["A3VRHybrid_settingPointerSource", _pointer, false];
missionNamespace setVariable ["A3VRHybrid_settingTurnRate", _turn, false];
missionNamespace setVariable ["A3VRHybrid_settingUiSize", _uiSize, false];
missionNamespace setVariable [
    "A3VRHybrid_settingMovementDirection", _movement, false];
missionNamespace setVariable [
    "A3VRHybrid_settingOpticFallback", _opticFallback, false];
missionNamespace setVariable ["A3VRHybrid_settingHandsRig", "off", false];
missionNamespace setVariable [
    "A3VRHybrid_settingProxyHud", _proxyHud, false];
missionNamespace setVariable [
    "A3VRHybrid_settingRecoil", _recoil, false];
missionNamespace setVariable [
    "A3VRHybrid_proxyMotionEnabled", _motion, false];
missionNamespace setVariable ["A3VRHybrid_debugEnabled", _debug, false];

// The avatar selection-cutout experiment is retired. Keep proxy cleanup
// unconditional to migrate an already-running session.
if (!(isNil "A3VRHybrid_fnc_proxyDeleteHands")) then {
    call A3VRHybrid_fnc_proxyDeleteHands;
};
if (!(isNil "A3VRHybrid_fnc_proxySetRenderMode")) then {
    call A3VRHybrid_fnc_proxySetRenderMode;
};
if (!(isNil "A3VRHybrid_fnc_proxyForceNativeHud")) then {
    call A3VRHybrid_fnc_proxyForceNativeHud;
};

"A3VRHybridCore" callExtension ("settings:aim=" + _aim);
"A3VRHybridCore" callExtension ("settings:pointer=" + _pointer);
"A3VRHybridCore" callExtension ("settings:turn=" + _turn);
"A3VRHybridCore" callExtension ("settings:ui=" + _uiSize);
"A3VRHybridCore" callExtension ("settings:movement=" + _movement);
"A3VRHybridCore" callExtension ("settings:optic=" + _opticFallback);
"A3VRHybridCore" callExtension (
    "settings:motion=" + (["off", "on"] select _motion));

profileNamespace setVariable ["A3VR_settingAimSource", _aim];
profileNamespace setVariable ["A3VR_settingPointerSource", _pointer];
profileNamespace setVariable ["A3VR_settingTurnRate", _turn];
profileNamespace setVariable ["A3VR_settingUiSize", _uiSize];
profileNamespace setVariable ["A3VR_settingMovementDirection", _movement];
profileNamespace setVariable ["A3VR_settingOpticFallback", _opticFallback];
profileNamespace setVariable ["A3VR_settingHandsRig", "off"];
profileNamespace setVariable ["A3VR_settingProxyHud", _proxyHud];
profileNamespace setVariable ["A3VR_settingExternalArms", false];
profileNamespace setVariable ["A3VR_settingRecoil", _recoil];
profileNamespace setVariable ["A3VR_settingMotionAim", _motion];
saveProfileNamespace;

diag_log format [
    "[A3VR] Settings: aim=%1 pointer=%2 turn=%3 ui=%4 movement=%5 opticFallback=%6 proxyHud=%7 recoil=%8 debug=%9 motion=%10",
    _aim, _pointer, _turn, _uiSize, _movement, _opticFallback,
    _proxyHud, _recoil, _debug, _motion
];
