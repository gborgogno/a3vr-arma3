class CfgPatches {
    class A3VR_Hybrid_Core {
        name = "A3VR Hybrid Core";
        author = "A3VR contributors";
        requiredVersion = 2.12;
        requiredAddons[] = {"A3_Functions_F"};
        units[] = {};
        weapons[] = {};
    };
};

class CfgFunctions {
    class A3VRHybrid {
        class Core {
            file = "\a3vr_hybrid\functions";
            class preStart { preStart = 1; };
            class postInit { postInit = 1; };
            class trackingLoop {};
            class drawLeftHand {};
            class leftHandDebugLoop {};
            class gameContextLoop {};
        };
    };
};
