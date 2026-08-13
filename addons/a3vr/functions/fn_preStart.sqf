if (!hasInterface) exitWith {};

private _legacyConflict = isClass (configFile >> "CfgPatches" >> "A3VR_Core");
uiNamespace setVariable ["A3VRHybrid_legacyConflict", _legacyConflict];
if (_legacyConflict) exitWith {
    diag_log "[A3VR Hybrid] Startup blocked: legacy @A3VR is enabled. Disable it and keep only @A3VR_Hybrid.";
};

private _version = "A3VRHybridCore" callExtension "version";
private _status = "A3VRHybridCore" callExtension "start";
diag_log format ["[A3VR] Early automatic runtime bootstrap: version=%1, status=%2", _version, _status];
