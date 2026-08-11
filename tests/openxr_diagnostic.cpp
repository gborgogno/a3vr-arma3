#include <array>
#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <thread>

extern "C" {
__declspec(dllimport) void __stdcall RVExtension(char*, unsigned int, const char*);
}

namespace {
std::string call(const char* command) {
    std::array<char, 16384> output{};
    RVExtension(output.data(), static_cast<unsigned int>(output.size()), command);
    return output.data();
}
}

int main(int argc, char** argv) {
    std::ofstream file;
    std::ostream* output = &std::cout;
    if (argc > 1) {
        file.open(argv[1], std::ios::trunc);
        output = &file;
    }
    *output << std::unitbuf;
    *output << "calling start\n";
    *output << "start: " << call("start") << '\n';
    std::string previous;
    bool tracking = false;
    for (int attempt = 0; attempt < 100; ++attempt) {
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        *output << "calling status " << attempt << '\n';
        const std::string status = call("status");
        if (status != previous) {
            *output << "status: " << status << '\n';
            previous = status;
        }
        if (status == "tracking") {
            tracking = true;
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            *output << "calling pose\n";
            *output << "pose: " << call("pose") << '\n';
            output->flush();
            std::_Exit(0);
        }
        if (status.starts_with("error:")) break;
    }
    *output << "diagnostic timeout" << '\n' << std::flush;
    std::_Exit(2);
}
