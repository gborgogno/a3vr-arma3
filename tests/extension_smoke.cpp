#include <array>
#include <cassert>
#include <chrono>
#include <iostream>
#include <string>
#include <thread>

#include "../src/game_context.hpp"

#ifndef A3VR_EXPECTED_VERSION
#define A3VR_EXPECTED_VERSION "dev"
#endif

extern "C" {
__declspec(dllimport) void __stdcall RVExtensionVersion(char*, unsigned int);
__declspec(dllimport) void __stdcall RVExtension(char*, unsigned int, const char*);
}

int main(const int argc, char** argv) {
    std::array<char, 4096> output{};
    if (argc > 1) {
        RVExtension(output.data(), static_cast<unsigned int>(output.size()), argv[1]);
        std::cout << output.data() << '\n';
        return 0;
    }
    // DllMain publishes the startup context from its loader-safe worker.
    // Give that worker a bounded interval before checking the named events.
    std::uint32_t startup_context{};
    for (int attempt = 0; attempt < 50; ++attempt) {
        startup_context = a3vr::game_context();
        if ((startup_context & a3vr::game_context_ui) != 0U &&
            (startup_context & a3vr::game_context_mouse_ui) != 0U) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    assert((startup_context & a3vr::game_context_ui) != 0U);
    assert((startup_context & a3vr::game_context_mouse_ui) != 0U);
    assert((startup_context & a3vr::game_context_gameplay) == 0U);
    RVExtensionVersion(output.data(), static_cast<unsigned int>(output.size()));
    assert(std::string(output.data()) == A3VR_EXPECTED_VERSION);

    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "start");
    const std::string start_status(output.data());
    assert(!start_status.empty());
    assert(!start_status.starts_with("error:"));
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "start");
    const std::string repeated_start_status(output.data());
    assert(!repeated_start_status.empty());
    assert(!repeated_start_status.starts_with("error:"));
    std::this_thread::sleep_for(std::chrono::milliseconds(500));

    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "status");
    const std::string status(output.data());
    assert(!status.empty());
    std::cout << "OpenXR status: " << status << '\n';

    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "pose");
    const std::string pose(output.data());
    assert(pose.starts_with('[') && pose.ends_with(']'));
    std::cout << "Pose sample: " << pose << '\n';

    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "motion_mode");
    const std::string motion_mode(output.data());
    assert(motion_mode == "LegacyRelative" || motion_mode == "AbsoluteWeapon");
    std::cout << "Motion mode: " << motion_mode << '\n';

    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "aim_feedback:0,1,0");
    assert(std::string(output.data()) == "ok");
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "aim_feedback:invalid");
    assert(std::string(output.data()) == "ok");

    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "haptic:shot");
    assert(std::string(output.data()) == "ok");
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "haptic:invalid");
    assert(std::string(output.data()) == "error: invalid haptic effect");

    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "settings:aim=left");
    assert(std::string(output.data()) == "ok");
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "settings:pointer=head");
    assert(std::string(output.data()) == "ok");
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "settings:turn=fast");
    assert(std::string(output.data()) == "ok");
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "settings:movement=head");
    assert(std::string(output.data()) == "ok");
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "settings:optic=grip");
    assert(std::string(output.data()) == "ok");
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "settings:motion=on");
    assert(std::string(output.data()) == "ok");
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "settings");
    const std::string settings(output.data());
    assert(settings.find("aim=left") != std::string::npos);
    assert(settings.find("pointer=head") != std::string::npos);
    assert(settings.find("turn=fast") != std::string::npos);
    assert(settings.find("movement=head") != std::string::npos);
    assert(settings.find("optic=grip") != std::string::npos);
    assert(settings.find("motion=on") != std::string::npos);
    assert((a3vr::game_context() & a3vr::game_option_native_ads) != 0U);
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "context:ui,mouse");
    assert(std::string(output.data()) == "ok");
    assert((a3vr::game_context() & a3vr::game_context_ui) != 0U);
    assert((a3vr::game_context() & a3vr::game_context_mouse_ui) != 0U);
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "context:gameplay");
    assert(std::string(output.data()) == "ok");
    assert((a3vr::game_context() & a3vr::game_context_gameplay) != 0U);
    assert((a3vr::game_context() & a3vr::game_context_mouse_ui) == 0U);
    assert((a3vr::game_context() & a3vr::game_context_radial) == 0U);
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "proxy_mode:on");
    assert(std::string(output.data()) == "ok");
    assert((a3vr::game_context() & a3vr::game_option_proxy_active) != 0U);
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "proxy_mode:off");
    assert(std::string(output.data()) == "ok");
    assert((a3vr::game_context() & a3vr::game_option_proxy_active) == 0U);
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()),
                "body_yaw:1.25");
    assert(std::string(output.data()) == "ok");
    output.fill('\0');
    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "recenter");
    assert(std::string(output.data()) == "ok");

    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "stop");
    assert(std::string(output.data()) == "server follows host lifetime");
    return 0;
}
