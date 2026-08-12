if (!hasInterface) exitWith {};

private _version = "A3VRCore" callExtension "version";
diag_log format ["[A3VR] Native extension version: %1", _version];

"A3VRCore" callExtension "start";
[] spawn A3VR_fnc_trackingLoop;
[] spawn A3VR_fnc_weaponProxyLoop;
