/*
    Tracking-only diagnostic loop. This deliberately does not take control of
    the player's camera yet; it publishes the latest native sample so missions
    and the future camera bridge can consume it safely.
*/
A3VR_tracking = [];

while {true} do {
    private _raw = "A3VRCore" callExtension "pose";
    private _sample = parseSimpleArray _raw;
    if (_sample isEqualType [] && {count _sample >= 7}) then {
        A3VR_tracking = _sample;
        missionNamespace setVariable ["A3VR_tracking", _sample, false];
    };
    uiSleep 0.01;
};
