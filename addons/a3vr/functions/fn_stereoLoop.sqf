/*
    Produces a real side-by-side game frame for the OpenXR runtime.

    The runtime's SBS path is deliberately only a compositor: it splits an
    already-stereo backbuffer into two OpenXR projection views. These two local
    RTT cameras are therefore the image authority. UI contexts disable the RTT
    overlay; the runtime presents the complete backbuffer as one comfortable
    menu surface to both eyes.
*/
if (!hasInterface) exitWith {};

if (!isNil "A3VRHybrid_stereoEachFrame" &&
    {A3VRHybrid_stereoEachFrame isEqualType 0} &&
    {A3VRHybrid_stereoEachFrame >= 0}) then {
    removeMissionEventHandler ["EachFrame", A3VRHybrid_stereoEachFrame];
};

A3VRHybrid_fnc_stereoDestroy = {
    if (!isNil "A3VRHybrid_stereoLeftCamera" &&
        {!isNull A3VRHybrid_stereoLeftCamera}) then {
        A3VRHybrid_stereoLeftCamera cameraEffect [
            "TERMINATE", "BACK", "a3vrleft"];
        camDestroy A3VRHybrid_stereoLeftCamera;
    };
    if (!isNil "A3VRHybrid_stereoRightCamera" &&
        {!isNull A3VRHybrid_stereoRightCamera}) then {
        A3VRHybrid_stereoRightCamera cameraEffect [
            "TERMINATE", "BACK", "a3vrright"];
        camDestroy A3VRHybrid_stereoRightCamera;
    };
    {
        if (!isNull _x) then {ctrlDelete _x;};
    } forEach [
        uiNamespace getVariable ["A3VRHybrid_stereoLeftControl", controlNull],
        uiNamespace getVariable ["A3VRHybrid_stereoRightControl", controlNull]
    ];
    A3VRHybrid_stereoLeftCamera = objNull;
    A3VRHybrid_stereoRightCamera = objNull;
    uiNamespace setVariable ["A3VRHybrid_stereoLeftControl", controlNull];
    uiNamespace setVariable ["A3VRHybrid_stereoRightControl", controlNull];
    uiNamespace setVariable ["A3VRHybrid_stereoDisplay", displayNull];
    A3VRHybrid_stereoRendering = false;
};

call A3VRHybrid_fnc_stereoDestroy;
A3VRHybrid_stereoPiPWarning = false;
A3VRHybrid_stereoReleasedProxyCamera = false;
A3VRHybrid_stereoFov = 1.50;
A3VRHybrid_stereoFovLog = -1;
A3VRHybrid_stereoHalfIpd = 0.032;
A3VRHybrid_stereoIpdLog = -1;

private _deadline = diag_tickTime + 30;
waitUntil {
    uiSleep 0.10;
    private _status = "A3VRHybridCore" callExtension "status";
    (_status find "depth SBS") >= 0 || {diag_tickTime >= _deadline}
};
private _runtimeStatus = "A3VRHybridCore" callExtension "status";
if ((_runtimeStatus find "depth SBS") < 0) exitWith {
    diag_log format [
        "[A3VR] Stereo source inactive because runtime status is %1",
        _runtimeStatus];
};

// Match the square Arma RTT cameras to the same symmetric angular field used
// by the OpenXR projection. A fixed 1.03 radian camera submitted with the
// headset's wider/asymmetric FOV stretched the edges while turning (fisheye).
A3VRHybrid_fnc_stereoResolveFov = {
    private _sample = missionNamespace getVariable [
        "A3VRHybrid_tracking", []];
    private _eyes = _sample param [7, []];
    if (count _eyes < 2) exitWith {A3VRHybrid_stereoFov};
    private _leftFov = (_eyes param [0, []]) param [1, []];
    private _rightFov = (_eyes param [1, []]) param [1, []];
    if (count _leftFov < 4 || {count _rightFov < 4}) exitWith {
        A3VRHybrid_stereoFov
    };
    private _horizontalHalf = 0.25 * (
        abs (_leftFov # 0) + abs (_leftFov # 1) +
        abs (_rightFov # 0) + abs (_rightFov # 1));
    private _verticalHalf = 0.25 * (
        abs (_leftFov # 2) + abs (_leftFov # 3) +
        abs (_rightFov # 2) + abs (_rightFov # 3));
    private _squareFov = 2 * (_horizontalHalf min _verticalHalf);
    (_squareFov max 1.10) min 1.75
};

// Use the headset's reported eye separation instead of assuming every user is
// exactly 64 mm.  A mismatched source IPD makes nearby geometry impossible to
// fuse even when the two RTT images are otherwise correct.
A3VRHybrid_fnc_stereoResolveHalfIpd = {
    private _sample = missionNamespace getVariable [
        "A3VRHybrid_tracking", []];
    private _eyes = _sample param [7, []];
    if (count _eyes < 2) exitWith {A3VRHybrid_stereoHalfIpd};
    private _leftPose = (_eyes param [0, []]) param [0, []];
    private _rightPose = (_eyes param [1, []]) param [0, []];
    if (count _leftPose < 5 || {count _rightPose < 5} ||
        {(_leftPose # 0) < 1} || {(_rightPose # 0) < 1}) exitWith {
        A3VRHybrid_stereoHalfIpd
    };
    private _ipd = vectorMagnitude (
        (_rightPose # 2) vectorDiff (_leftPose # 2));
    ((_ipd * 0.5) max 0.025) min 0.038
};

A3VRHybrid_fnc_stereoEnsure = {
    private _display = findDisplay 46;
    if (isNull _display) exitWith {false};
    if (!isPiPEnabled) exitWith {
        if (!A3VRHybrid_stereoPiPWarning) then {
            A3VRHybrid_stereoPiPWarning = true;
            systemChat "A3VR stereo needs Picture-in-Picture enabled.";
            diag_log "[A3VR] Stereo RTT unavailable: Picture-in-Picture is disabled";
        };
        false
    };

    private _storedDisplay = uiNamespace getVariable [
        "A3VRHybrid_stereoDisplay", displayNull];
    if (!(_display isEqualTo _storedDisplay)) then {
        call A3VRHybrid_fnc_stereoDestroy;
        uiNamespace setVariable ["A3VRHybrid_stereoDisplay", _display];
    };
    private _desiredFov = call A3VRHybrid_fnc_stereoResolveFov;
    A3VRHybrid_stereoFov = _desiredFov;
    if (isNull A3VRHybrid_stereoLeftCamera) then {
        A3VRHybrid_stereoLeftCamera = "camera" camCreate [0, 0, 0];
        A3VRHybrid_stereoLeftCamera camSetFov _desiredFov;
        A3VRHybrid_stereoLeftCamera camCommit 0;
    };
    if (isNull A3VRHybrid_stereoRightCamera) then {
        A3VRHybrid_stereoRightCamera = "camera" camCreate [0, 0, 0];
        A3VRHybrid_stereoRightCamera camSetFov _desiredFov;
        A3VRHybrid_stereoRightCamera camCommit 0;
    };
    if (abs (_desiredFov - A3VRHybrid_stereoFovLog) > 0.001) then {
        A3VRHybrid_stereoLeftCamera camSetFov _desiredFov;
        A3VRHybrid_stereoRightCamera camSetFov _desiredFov;
        A3VRHybrid_stereoLeftCamera camCommit 0;
        A3VRHybrid_stereoRightCamera camCommit 0;
        A3VRHybrid_stereoFovLog = _desiredFov;
        diag_log format ["[A3VR] Stereo symmetric FOV=%1 rad", _desiredFov];
    };
    private _leftControl = uiNamespace getVariable [
        "A3VRHybrid_stereoLeftControl", controlNull];
    if (isNull _leftControl) then {
        _leftControl = _display ctrlCreate ["RscPicture", -1];
        _leftControl ctrlSetText
            "#(argb,1024,1024,1)r2t(a3vrleft,1.0)";
        _leftControl ctrlSetTextColor [1, 1, 1, 1];
        uiNamespace setVariable [
            "A3VRHybrid_stereoLeftControl", _leftControl];
    };
    private _rightControl = uiNamespace getVariable [
        "A3VRHybrid_stereoRightControl", controlNull];
    if (isNull _rightControl) then {
        _rightControl = _display ctrlCreate ["RscPicture", -1];
        _rightControl ctrlSetText
            "#(argb,1024,1024,1)r2t(a3vrright,1.0)";
        _rightControl ctrlSetTextColor [1, 1, 1, 1];
        uiNamespace setVariable [
            "A3VRHybrid_stereoRightControl", _rightControl];
    };
    private _halfWidth = safeZoneWAbs * 0.5;
    _leftControl ctrlSetPosition [
        safeZoneXAbs, safeZoneY, _halfWidth, safeZoneH];
    _rightControl ctrlSetPosition [
        safeZoneXAbs + _halfWidth, safeZoneY, _halfWidth, safeZoneH];
    _leftControl ctrlCommit 0;
    _rightControl ctrlCommit 0;
    true
};

A3VRHybrid_stereoEachFrame = addMissionEventHandler ["EachFrame", {
    if !(call A3VRHybrid_fnc_stereoEnsure) exitWith {};
    private _gameplay = missionNamespace getVariable [
        "A3VRHybrid_contextGameplay", false];
    private _ui = missionNamespace getVariable [
        "A3VRHybrid_contextUi", false];
    private _renderStereo = _gameplay && {!_ui} && {!visibleMap} &&
        {!isNull player} && {alive player};
    private _leftControl = uiNamespace getVariable [
        "A3VRHybrid_stereoLeftControl", controlNull];
    private _rightControl = uiNamespace getVariable [
        "A3VRHybrid_stereoRightControl", controlNull];
    if (!isNull _leftControl) then {_leftControl ctrlShow _renderStereo;};
    if (!isNull _rightControl) then {_rightControl ctrlShow _renderStereo;};

    // Keep the RTT producers alive across map, inventory and A3VR-menu
    // transitions.  Terminating and immediately re-opening both cameraEffect
    // targets leaves their textures black for several seconds (or permanently
    // on some drivers).  Hiding the two controls is sufficient for complete UI.
    if (!_renderStereo) exitWith {};
    if (!A3VRHybrid_stereoRendering) then {
        // cameraEffect cannot mix a full-screen camera with RTT sources. The
        // proxy camera remains a pose object; only its full-screen effect ends.
        if (missionNamespace getVariable [
            "A3VRHybrid_proxyActive", false] &&
            {!isNull A3VRHybrid_proxyCamera}) then {
            A3VRHybrid_proxyCamera cameraEffect ["TERMINATE", "BACK"];
            A3VRHybrid_stereoReleasedProxyCamera = true;
        };
        A3VRHybrid_stereoLeftCamera cameraEffect [
            "INTERNAL", "BACK", "a3vrleft"];
        A3VRHybrid_stereoRightCamera cameraEffect [
            "INTERNAL", "BACK", "a3vrright"];
        A3VRHybrid_stereoRendering = true;
        diag_log "[A3VR] Stereo RTT source active: 1024x1024 per eye";
    };

    private _center = eyePos player;
    private _forward = vectorNormalized (getCameraViewDirection player);
    private _up = [0, 0, 1];
    if (missionNamespace getVariable [
        "A3VRHybrid_proxyActive", false] &&
        {!isNull A3VRHybrid_proxyCamera}) then {
        _center = getPosWorld A3VRHybrid_proxyCamera;
        _forward = vectorNormalized (vectorDir A3VRHybrid_proxyCamera);
        _up = vectorNormalized (vectorUp A3VRHybrid_proxyCamera);
    } else {
        private _rightFlat = vectorNormalized
            (_forward vectorCrossProduct [0, 0, 1]);
        if (vectorMagnitude _rightFlat > 0.1) then {
            _up = vectorNormalized (_rightFlat vectorCrossProduct _forward);
        };
    };
    private _right = vectorNormalized (_forward vectorCrossProduct _up);
    _up = vectorNormalized (_right vectorCrossProduct _forward);
    private _halfIpd = call A3VRHybrid_fnc_stereoResolveHalfIpd;
    A3VRHybrid_stereoHalfIpd = _halfIpd;
    if (abs (_halfIpd - A3VRHybrid_stereoIpdLog) > 0.0001) then {
        A3VRHybrid_stereoIpdLog = _halfIpd;
        diag_log format ["[A3VR] Stereo source IPD=%1 mm", _halfIpd * 2000];
    };
    A3VRHybrid_stereoLeftCamera setPosWorld
        (_center vectorDiff (_right vectorMultiply _halfIpd));
    A3VRHybrid_stereoRightCamera setPosWorld
        (_center vectorAdd (_right vectorMultiply _halfIpd));
    A3VRHybrid_stereoLeftCamera setVectorDirAndUp [_forward, _up];
    A3VRHybrid_stereoRightCamera setVectorDirAndUp [_forward, _up];
}];

diag_log "[A3VR] Stereo SBS source initialized";
