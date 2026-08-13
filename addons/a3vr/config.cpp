class CfgPatches {
    class A3VR_Core {
        name = "A3VR Core";
        author = "A3VR contributors";
        requiredVersion = 2.12;
        requiredAddons[] = {"A3_Functions_F"};
        units[] = {};
        weapons[] = {};
    };
};

class CfgFunctions {
    class A3VR {
        class Core {
            file = "\a3vr\functions";
            class postInit { postInit = 1; };
            class trackingLoop {};
            class drawLeftHand {};
            class leftHandDebugLoop {};
        };
    };
};
