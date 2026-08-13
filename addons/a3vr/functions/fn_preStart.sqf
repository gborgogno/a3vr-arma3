if (!hasInterface) exitWith {};

private _version = "A3VRCore" callExtension "version";
private _status = "A3VRCore" callExtension "start";
diag_log format ["[A3VR] Early automatic runtime bootstrap: version=%1, status=%2", _version, _status];
