#include <array>
#include <cassert>
#include <chrono>
#include <iostream>
#include <string>
#include <thread>

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
    RVExtensionVersion(output.data(), static_cast<unsigned int>(output.size()));
    assert(std::string(output.data()) == A3VR_EXPECTED_VERSION);

    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "start");
    const std::string start_status(output.data());
    assert(!start_status.empty());
    assert(!start_status.starts_with("error:"));
    std::this_thread::sleep_for(std::chrono::milliseconds(500));

    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "status");
    const std::string status(output.data());
    assert(!status.empty());
    std::cout << "OpenXR status: " << status << '\n';

    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "pose");
    const std::string pose(output.data());
    assert(pose.starts_with('[') && pose.ends_with(']'));
    std::cout << "Pose sample: " << pose << '\n';

    RVExtension(output.data(), static_cast<unsigned int>(output.size()), "stop");
    assert(std::string(output.data()) == "server follows host lifetime");
    return 0;
}
