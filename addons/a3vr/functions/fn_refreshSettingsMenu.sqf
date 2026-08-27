/* Refresh labels in the already-open settings display. */
disableSerialization;
private _display = uiNamespace getVariable [
    "A3VRHybrid_settingsDisplay", displayNull];
if (isNull _display) exitWith {};

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
private _debug = missionNamespace getVariable [
    "A3VRHybrid_debugEnabled", false];
private _proxyEnabled = missionNamespace getVariable [
    "A3VRHybrid_proxyEnabled", true];
private _motion = missionNamespace getVariable [
    "A3VRHybrid_proxyMotionEnabled", true];

(_display displayCtrl 7311) ctrlSetText (
    ["Right controller", "Left controller"] select (_aim isEqualTo "left"));
(_display displayCtrl 7313) ctrlSetText (
    ["Right controller", "Head gaze"] select (_pointer isEqualTo "head"));
(_display displayCtrl 7315) ctrlSetText (switch (_turn) do {
    case "comfort": {"Comfort"};
    case "normal": {"Normal"};
    default {"Fast"};
});
(_display displayCtrl 7317) ctrlSetText (
    ["Full frame", "Larger"] select (_uiSize isEqualTo "large"));
(_display displayCtrl 7319) ctrlSetText (
    ["Off", "On"] select _debug);
(_display displayCtrl 7324) ctrlSetText (
    ["Body direction", "Head direction"] select (_movement isEqualTo "head"));
(_display displayCtrl 7326) ctrlSetText (
    ["Off (physical ironsights)", "On (Arma native ADS)"] select
        (_opticFallback isEqualTo "grip"));
(_display displayCtrl 7334) ctrlSetText (
    ["Off", "On (objectives + squad)"] select _proxyHud);
(_display displayCtrl 7330) ctrlSetText (switch (_recoil) do {
    case "off": {"Off"};
    case "comfort": {"Comfort"};
    default {"Normal"};
});
(_display displayCtrl 7332) ctrlSetText (
    ["Native motion", "VR proxy"] select _proxyEnabled);
(_display displayCtrl 7336) ctrlSetText (
    ["Frozen", "Live controller"] select _motion);
