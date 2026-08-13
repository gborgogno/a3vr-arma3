/*
    Draw a controller-derived left-hand skeleton in camera/world space.
    OpenXR tracking arrives in a stable room basis. It is first expressed in
    the current headset basis, then positionCameraToWorld applies Arma's live
    camera transform. This prevents body yaw from rotating the hand twice.
*/
private _sample = missionNamespace getVariable ["A3VRHybrid_tracking", []];
if (!(_sample isEqualType []) || {count _sample < 10}) exitWith {};

private _head = _sample # 4;
private _hand = _sample # 5;
private _curls = _sample # 9;
if (count _head < 5 || {count _hand < 5} || {count _curls < 5}) exitWith {};
if ((_head # 0) < 1 || {(_head # 1) < 1} || {(_hand # 0) < 1} || {(_hand # 1) < 1}) exitWith {};

private _headPosition = _head # 2;
private _headForward = vectorNormalized (_head # 3);
private _headUp = vectorNormalized (_head # 4);
private _headRight = vectorNormalized (_headForward vectorCrossProduct _headUp);
_headUp = vectorNormalized (_headRight vectorCrossProduct _headForward);

private _toHeadLocal = {
    params ["_vector", "_right", "_forward", "_up"];
    [
        _vector vectorDotProduct _right,
        _vector vectorDotProduct _forward,
        _vector vectorDotProduct _up
    ]
};

private _relativePosition = (_hand # 2) vectorDiff _headPosition;
private _localPosition = [_relativePosition, _headRight, _headForward, _headUp] call _toHeadLocal;
private _localForward = [_hand # 3, _headRight, _headForward, _headUp] call _toHeadLocal;
private _localUp = [_hand # 4, _headRight, _headForward, _headUp] call _toHeadLocal;

private _cameraOrigin = positionCameraToWorld [0, 0, 0];
private _handPosition = positionCameraToWorld _localPosition;
private _handForward = vectorNormalized ((positionCameraToWorld _localForward) vectorDiff _cameraOrigin);
private _handUp = vectorNormalized ((positionCameraToWorld _localUp) vectorDiff _cameraOrigin);
private _handRight = vectorNormalized (_handForward vectorCrossProduct _handUp);
_handUp = vectorNormalized (_handRight vectorCrossProduct _handForward);

private _wrist = _handPosition vectorAdd (_handForward vectorMultiply -0.045);
private _palmBase = _handPosition vectorAdd (_handForward vectorMultiply -0.012);
private _knuckleCenter = _handPosition vectorAdd (_handForward vectorMultiply 0.065);
private _palmHalfWidth = 0.038;

private _palmBaseOuter = _palmBase vectorAdd (_handRight vectorMultiply -_palmHalfWidth);
private _palmBaseInner = _palmBase vectorAdd (_handRight vectorMultiply _palmHalfWidth);
private _knuckleOuter = _knuckleCenter vectorAdd (_handRight vectorMultiply -_palmHalfWidth);
private _knuckleInner = _knuckleCenter vectorAdd (_handRight vectorMultiply _palmHalfWidth);
private _palmColor = [0.18, 0.82, 1.0, 0.96];

drawLine3D [_wrist, _palmBaseOuter, _palmColor, 5];
drawLine3D [_wrist, _palmBaseInner, _palmColor, 5];
drawLine3D [_palmBaseOuter, _palmBaseInner, _palmColor, 5];
drawLine3D [_palmBaseOuter, _knuckleOuter, _palmColor, 5];
drawLine3D [_palmBaseInner, _knuckleInner, _palmColor, 5];
drawLine3D [_knuckleOuter, _knuckleInner, _palmColor, 5];

// RGB wrist axes make alignment errors unambiguous during calibration.
drawLine3D [_wrist, _wrist vectorAdd (_handRight vectorMultiply 0.045), [1, 0.15, 0.1, 0.95], 4];
drawLine3D [_wrist, _wrist vectorAdd (_handForward vectorMultiply 0.06), [0.15, 1, 0.2, 0.95], 4];
drawLine3D [_wrist, _wrist vectorAdd (_handUp vectorMultiply 0.045), [0.2, 0.45, 1, 0.95], 4];

private _clampCurl = {
    params ["_value"];
    (_value max 0) min 1
};

private _drawFinger = {
    params ["_start", "_side", "_curl", "_lengths", "_color"];
    private _current = _start;
    private _flatForward = vectorNormalized (
        (_handForward vectorMultiply (1 - abs _side)) vectorAdd
        (_handRight vectorMultiply _side)
    );
    private _segmentCount = count _lengths;
    {
        private _progress = (_forEachIndex + 1) / _segmentCount;
        private _angle = 4 + (_curl * (18 + 82 * _progress));
        private _segmentDirection = vectorNormalized (
            (_flatForward vectorMultiply (cos _angle)) vectorAdd
            ((_handUp vectorMultiply -1) vectorMultiply (sin _angle))
        );
        private _next = _current vectorAdd (_segmentDirection vectorMultiply _x);
        drawLine3D [_current, _next, _color, 5];
        _current = _next;
    } forEach _lengths;
};

private _fingerColor = [0.35, 0.9, 1, 1];
private _indexColor = [1, 0.72, 0.18, 1];
private _thumbColor = [0.85, 0.35, 1, 1];

[
    _knuckleCenter vectorAdd (_handRight vectorMultiply -0.027),
    -0.04,
    [(_curls # 4)] call _clampCurl,
    [0.026, 0.021, 0.017],
    _fingerColor
] call _drawFinger;
[
    _knuckleCenter vectorAdd (_handRight vectorMultiply -0.009),
    -0.015,
    [(_curls # 3)] call _clampCurl,
    [0.03, 0.024, 0.018],
    _fingerColor
] call _drawFinger;
[
    _knuckleCenter vectorAdd (_handRight vectorMultiply 0.010),
    0,
    [(_curls # 2)] call _clampCurl,
    [0.032, 0.026, 0.019],
    _fingerColor
] call _drawFinger;
[
    _knuckleCenter vectorAdd (_handRight vectorMultiply 0.029),
    0.015,
    [(_curls # 1)] call _clampCurl,
    [0.03, 0.024, 0.018],
    _indexColor
] call _drawFinger;

private _thumbBase = _palmBase vectorAdd (_handForward vectorMultiply 0.026);
_thumbBase = _thumbBase vectorAdd (_handRight vectorMultiply 0.039);
[
    _thumbBase,
    0.62,
    [(_curls # 0)] call _clampCurl,
    [0.029, 0.023, 0.018],
    _thumbColor
] call _drawFinger;
