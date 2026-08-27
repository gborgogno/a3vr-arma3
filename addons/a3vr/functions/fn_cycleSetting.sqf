/* Cycle one setting from the in-game A3VR menu. */
params ["_setting"];

private _cycle = {
    params ["_current", "_values"];
    private _index = _values find _current;
    if (_index < 0) then {_index = 0;} else {
        _index = (_index + 1) mod (count _values);
    };
    _values # _index
};

switch (_setting) do {
    case "aim": {
        private _current = missionNamespace getVariable [
            "A3VRHybrid_settingAimSource", "right"];
        missionNamespace setVariable [
            "A3VRHybrid_settingAimSource",
            [_current, ["right", "left"]] call _cycle, false];
    };
    case "pointer": {
        private _current = missionNamespace getVariable [
            "A3VRHybrid_settingPointerSource", "head"];
        missionNamespace setVariable [
            "A3VRHybrid_settingPointerSource",
            [_current, ["head", "controller"]] call _cycle, false];
    };
    case "turn": {
        private _current = missionNamespace getVariable [
            "A3VRHybrid_settingTurnRate", "fast"];
        missionNamespace setVariable [
            "A3VRHybrid_settingTurnRate",
            [_current, ["comfort", "normal", "fast"]] call _cycle, false];
    };
    case "ui": {
        private _current = missionNamespace getVariable [
            "A3VRHybrid_settingUiSize", "full"];
        missionNamespace setVariable [
            "A3VRHybrid_settingUiSize",
            [_current, ["full", "large"]] call _cycle, false];
    };
    case "movement": {
        private _current = missionNamespace getVariable [
            "A3VRHybrid_settingMovementDirection", "head"];
        missionNamespace setVariable [
            "A3VRHybrid_settingMovementDirection",
            [_current, ["head", "body"]] call _cycle, false];
    };
    case "optic": {
        private _current = missionNamespace getVariable [
            "A3VRHybrid_settingOpticFallback", "grip"];
        missionNamespace setVariable [
            "A3VRHybrid_settingOpticFallback",
            [_current, ["grip", "off"]] call _cycle, false];
    };
    case "hud": {
        missionNamespace setVariable [
            "A3VRHybrid_settingProxyHud",
            !(missionNamespace getVariable [
                "A3VRHybrid_settingProxyHud", true]), false];
    };
    case "recoil": {
        private _current = missionNamespace getVariable [
            "A3VRHybrid_settingRecoil", "normal"];
        missionNamespace setVariable [
            "A3VRHybrid_settingRecoil",
            [_current, ["off", "comfort", "normal"]] call _cycle,
            false];
    };
    case "weapon": {
        if (!(isNil "A3VRHybrid_fnc_toggleWeaponProxy")) then {
            call A3VRHybrid_fnc_toggleWeaponProxy;
        };
    };
    case "motion": {
        missionNamespace setVariable [
            "A3VRHybrid_proxyMotionEnabled",
            !(missionNamespace getVariable [
                "A3VRHybrid_proxyMotionEnabled", true]), false];
        A3VRHybrid_proxyFrozenTarget = [];
    };
    case "debug": {
        missionNamespace setVariable [
            "A3VRHybrid_debugEnabled",
            !(missionNamespace getVariable ["A3VRHybrid_debugEnabled", false]),
            false];
    };
};

call A3VRHybrid_fnc_applySettings;
call A3VRHybrid_fnc_refreshSettingsMenu;
