if (!hasInterface) exitWith {};

if (uiNamespace getVariable ["A3VRHybrid_legacyConflict", false]) exitWith {
    systemChat "A3VR Hybrid disabled: legacy @A3VR is also enabled. Restart with only @A3VR_Hybrid.";
    diag_log "[A3VR Hybrid] Post-init stopped because legacy @A3VR is enabled.";
};

private _version = "A3VRHybridCore" callExtension "version";
private _status = "A3VRHybridCore" callExtension "start";
diag_log format ["[A3VR] Runtime post-init check: version=%1, status=%2", _version, _status];
[] spawn A3VRHybrid_fnc_trackingLoop;
