class CfgPatches {
    class A3VR_Hybrid_Core {
        name = "A3VR Hybrid Core";
        author = "A3VR contributors";
        requiredVersion = 2.12;
        requiredAddons[] = {"A3_Functions_F", "A3_Data_F_ParticleEffects"};
        units[] = {};
        weapons[] = {};
    };
};

class CfgCloudlets {
    class RifleAssaultCloud1;
    class MachineGunCloud1;
    // The stock weapon classes reference directionX/positionX variables that
    // only exist inside an engine-owned weapon effect. Script particle sources
    // need resolved numeric values; all stock texture, colour and lifetime
    // behaviour remains inherited.
    class A3VR_RifleMuzzleCloud: RifleAssaultCloud1 {
        moveVelocity[] = {0, 0, 0};
        position[] = {0, 0, 0};
        MoveVelocityVar[] = {0.35, 0.35, 0.35};
    };
    class A3VR_MachineGunMuzzleCloud: MachineGunCloud1 {
        moveVelocity[] = {0, 0, 0};
        position[] = {0, 0, 0};
        MoveVelocityVar[] = {0.45, 0.45, 0.45};
    };
};

class CfgFunctions {
    class A3VRHybrid {
        class Core {
            file = "\a3vr_hybrid\functions";
            class preStart { preStart = 1; };
            class postInit { postInit = 1; };
            class trackingLoop {};
            class stereoLoop {};
            class gameContextLoop {};
            class applySettings {};
            class cycleSetting {};
            class refreshSettingsMenu {};
            class openSettingsMenu {};
            class settingsMenuLoop {};
            class trackingDebugLoop {};
            class weaponProxyLoop {};
        };
    };
};
