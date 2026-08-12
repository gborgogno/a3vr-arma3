#include "openxr_tracker.hpp"
#include "shared_state.hpp"

#include <chrono>
#include <cstdlib>
#include <string_view>
#include <thread>
#include <windows.h>

int main(int argc, char** argv) {
    HANDLE instance_mutex = CreateMutexA(nullptr, TRUE, "Local\\A3VR_Server_Instance_v24");
    if (instance_mutex == nullptr || GetLastError() == ERROR_ALREADY_EXISTS) return 0;

    DWORD parent_pid = 0;
    for (int index = 1; index + 1 < argc; ++index) {
        if (std::string_view(argv[index]) == "--parent") {
            parent_pid = static_cast<DWORD>(std::strtoul(argv[index + 1], nullptr, 10));
        }
    }
    HANDLE parent = parent_pid != 0 ? OpenProcess(SYNCHRONIZE, FALSE, parent_pid) : nullptr;
    const auto start_parent_watchdog = [](HANDLE watched_parent) {
        // This watcher must never call OpenXR or wait for the tracker thread.
        // TerminateProcess avoids loader-lock/runtime shutdown deadlocks when a
        // vendor OpenXR call remains blocked after Arma has already exited.
        std::thread([watched_parent] {
            WaitForSingleObject(watched_parent, INFINITE);
            TerminateProcess(GetCurrentProcess(), 0);
        }).detach();
    };
    if (parent != nullptr) start_parent_watchdog(parent);

    a3vr::SharedState shared;
    if (!shared.create()) return 2;
    auto& tracker = a3vr::OpenXrTracker::instance();
    tracker.start();

    auto next_retry = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (true) {
        shared.publish(tracker.snapshot(), tracker.status());
        // A pre-launcher starts this process before Arma so FreeTrack is visible
        // during device enumeration. Adopt the game as soon as its render hook
        // publishes a source PID, then enforce the same lifetime relationship.
        if (parent == nullptr) {
            a3vr::SharedRenderFrame render{};
            if (shared.read_render(render) && render.source_pid != 0) {
                parent = OpenProcess(SYNCHRONIZE, FALSE, render.source_pid);
                if (parent != nullptr) start_parent_watchdog(parent);
            }
        }
        if (parent != nullptr && WaitForSingleObject(parent, 0) == WAIT_OBJECT_0)
            TerminateProcess(GetCurrentProcess(), 0);
        const auto now = std::chrono::steady_clock::now();
        if (!tracker.running() && now >= next_retry) {
            tracker.start();
            next_retry = now + std::chrono::seconds(2);
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}
