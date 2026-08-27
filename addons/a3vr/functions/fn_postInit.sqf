if (!hasInterface) exitWith {};

if (uiNamespace getVariable ["A3VRHybrid_legacyConflict", false]) exitWith {
    systemChat "A3VR Hybrid disabled: legacy @A3VR is also enabled. Restart with only @A3VR_Hybrid.";
    diag_log "[A3VR Hybrid] Post-init stopped because legacy @A3VR is enabled.";
};

private _version = "A3VRHybridCore" callExtension "version";
private _status = "A3VRHybridCore" callExtension "start";
diag_log format ["[A3VR] Runtime post-init check: version=%1, status=%2", _version, _status];

private _savedAimSource = profileNamespace getVariable [
    "A3VR_settingAimSource", "right"];
// Migrate the previous controller/head experiment safely: head aiming is no
// longer a valid mode, so every old value returns to the right controller.
if !(_savedAimSource in ["right", "left"]) then {
    _savedAimSource = "right";
};
missionNamespace setVariable [
    "A3VRHybrid_settingAimSource", _savedAimSource, false];
missionNamespace setVariable [
    "A3VRHybrid_settingPointerSource",
    profileNamespace getVariable ["A3VR_settingPointerSource", "head"], false];
missionNamespace setVariable [
    "A3VRHybrid_settingTurnRate",
    profileNamespace getVariable ["A3VR_settingTurnRate", "fast"], false];
missionNamespace setVariable [
    "A3VRHybrid_settingUiSize",
    profileNamespace getVariable ["A3VR_settingUiSize", "full"], false];
missionNamespace setVariable [
    "A3VRHybrid_settingMovementDirection",
    profileNamespace getVariable [
        "A3VR_settingMovementDirection", "head"], false];
missionNamespace setVariable [
    "A3VRHybrid_settingOpticFallback",
    profileNamespace getVariable ["A3VR_settingOpticFallback", "grip"],
    false];
// The avatar-selection arm cutout is retired: Arma cannot copy a live Man
// skeleton pose into the simple objects used by the proxy. Migrate every
// existing profile back to off so an older saved experiment cannot respawn it.
missionNamespace setVariable ["A3VRHybrid_settingHandsRig", "off", false];
missionNamespace setVariable [
    "A3VRHybrid_settingProxyHud",
    profileNamespace getVariable ["A3VR_settingProxyHud", true], false];
missionNamespace setVariable [
    "A3VRHybrid_settingRecoil",
    profileNamespace getVariable ["A3VR_settingRecoil", "normal"], false];
// Diagnostics are session-only and must never start as floating geometry.
missionNamespace setVariable ["A3VRHybrid_debugEnabled", false, false];
missionNamespace setVariable ["A3VRHybrid_ikArmsVisible", false, false];
missionNamespace setVariable ["A3VRHybrid_externalArmObjects", [], false];
missionNamespace setVariable ["A3VRHybrid_externalArmRigVisible", false, false];
missionNamespace setVariable ["A3VRHybrid_externalArmsFirstDrawLogged", false, false];
// External arm models and the compact combat HUD are retired. Proxy navigation
// markers are a separate, optional Draw3D layer controlled in the A3VR menu.
// The Windows hardware cursor is not part of the captured D3D11 backbuffer.
// Draw a capture-safe equivalent and guide ray in every real UI context.
missionNamespace setVariable ["A3VRHybrid_uiCursorEnabled", true, false];
missionNamespace setVariable ["A3VRHybrid_contextGameplay", false, false];
missionNamespace setVariable ["A3VRHybrid_contextUi", false, false];
missionNamespace setVariable [
    "A3VRHybrid_proxyMotionEnabled",
    profileNamespace getVariable ["A3VR_settingMotionAim", true], false];
call A3VRHybrid_fnc_applySettings;

[] spawn A3VRHybrid_fnc_trackingLoop;
[] spawn A3VRHybrid_fnc_gameContextLoop;
[] spawn A3VRHybrid_fnc_stereoLoop;
[] spawn A3VRHybrid_fnc_settingsMenuLoop;
[] spawn A3VRHybrid_fnc_trackingDebugLoop;
[] spawn A3VRHybrid_fnc_weaponProxyLoop;
missionNamespace setVariable ["A3VRHybrid_weaponVisualActive", false, false];
diag_log format ["[A3VR] Hybrid %1 stereo/proxy active", _version];
