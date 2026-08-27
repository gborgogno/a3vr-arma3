#include "openxr_tracker.hpp"
#include "shared_state.hpp"
#include "game_context.hpp"

#include <chrono>
#include <cstdlib>
#include <cwchar>
#include <filesystem>
#include <string>
#include <string_view>
#include <thread>
#include <tlhelp32.h>
#include <windows.h>

namespace {

DWORD find_arma_process() noexcept {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) return 0;
    PROCESSENTRY32W entry{sizeof(entry)};
    DWORD result{};
    if (Process32FirstW(snapshot, &entry)) {
        do {
            if (_wcsicmp(entry.szExeFile, L"arma3_x64.exe") == 0) {
                result = entry.th32ProcessID;
                break;
            }
        } while (Process32NextW(snapshot, &entry));
    }
    CloseHandle(snapshot);
    return result;
}

bool process_is_arma(const DWORD pid) noexcept {
    if (pid == 0) return false;

    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (process == nullptr) return false;

    std::wstring image_path(32768, L'\0');
    DWORD image_path_size = static_cast<DWORD>(image_path.size());
    const bool queried = QueryFullProcessImageNameW(
        process, 0, image_path.data(), &image_path_size) != FALSE;
    CloseHandle(process);
    if (!queried || image_path_size == 0) return false;

    const wchar_t* filename = std::wcsrchr(image_path.c_str(), L'\\');
    filename = filename == nullptr ? image_path.c_str() : filename + 1;
    return _wcsicmp(filename, L"arma3_x64.exe") == 0;
}

bool module_is_loaded(const DWORD pid, const wchar_t* module_name) noexcept {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid);
    if (snapshot == INVALID_HANDLE_VALUE) return false;
    MODULEENTRY32W entry{sizeof(entry)};
    bool found{};
    if (Module32FirstW(snapshot, &entry)) {
        do {
            if (_wcsicmp(entry.szModule, module_name) == 0) {
                found = true;
                break;
            }
        } while (Module32NextW(snapshot, &entry));
    }
    CloseHandle(snapshot);
    return found;
}

std::filesystem::path extension_path() {
    wchar_t executable[MAX_PATH]{};
    const DWORD length = GetModuleFileNameW(nullptr, executable, MAX_PATH);
    if (length == 0 || length >= MAX_PATH) return {};
    return std::filesystem::path(executable).parent_path() / L"A3VRHybridCore_x64.dll";
}

bool preload_extension(const DWORD pid, const std::filesystem::path& path) noexcept {
    if (!process_is_arma(pid)) return false;
    if (module_is_loaded(pid, L"A3VRHybridCore_x64.dll")) return true;
    if (path.empty() || !std::filesystem::exists(path)) return false;
    HANDLE process = OpenProcess(PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION |
        PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ, FALSE, pid);
    if (process == nullptr) return false;
    const std::wstring dll_path = path.wstring();
    const SIZE_T bytes = (dll_path.size() + 1) * sizeof(wchar_t);
    void* remote_path = VirtualAllocEx(process, nullptr, bytes,
        MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    bool loaded{};
    if (remote_path != nullptr &&
        WriteProcessMemory(process, remote_path, dll_path.c_str(), bytes, nullptr)) {
        const HMODULE kernel = GetModuleHandleW(L"kernel32.dll");
        const auto load_library = kernel != nullptr
            ? GetProcAddress(kernel, "LoadLibraryW") : nullptr;
        if (load_library != nullptr) {
            HANDLE thread = CreateRemoteThread(process, nullptr, 0,
                reinterpret_cast<LPTHREAD_START_ROUTINE>(load_library),
                remote_path, 0, nullptr);
            if (thread != nullptr) {
                if (WaitForSingleObject(thread, 5000) == WAIT_OBJECT_0) {
                    DWORD module_result{};
                    loaded = GetExitCodeThread(thread, &module_result) && module_result != 0;
                }
                CloseHandle(thread);
            }
        }
    }
    if (remote_path != nullptr) VirtualFreeEx(process, remote_path, 0, MEM_RELEASE);
    CloseHandle(process);
    return loaded || module_is_loaded(pid, L"A3VRHybridCore_x64.dll");
}

} // namespace

int main(int argc, char** argv) {
    HANDLE instance_mutex = CreateMutexA(nullptr, TRUE, "Local\\A3VR_Server_Instance_v31");
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
    // Logo/loading/main menu exist before SQF can classify a display. Keep
    // that entire startup path on the physical mouse from the first frame.
    a3vr::set_game_context(
        a3vr::game_context_ui | a3vr::game_context_mouse_ui);
    auto& tracker = a3vr::OpenXrTracker::instance();
    tracker.start();

    auto next_retry = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    auto next_preload = std::chrono::steady_clock::now();
    const std::filesystem::path core_extension = extension_path();
    while (true) {
        shared.publish(tracker.snapshot(), tracker.status());
        // A pre-launcher starts this process before Arma so FreeTrack is visible
        // during device enumeration. Adopt the game as soon as its render hook
        // publishes a source PID, then enforce the same lifetime relationship.
        if (parent == nullptr) {
            const auto now = std::chrono::steady_clock::now();
            if (now >= next_preload) {
                const DWORD game_pid = find_arma_process();
                if (game_pid != 0 && preload_extension(game_pid, core_extension)) {
                    parent = OpenProcess(SYNCHRONIZE, FALSE, game_pid);
                    if (parent != nullptr) start_parent_watchdog(parent);
                }
                next_preload = now + std::chrono::milliseconds(250);
            }
            a3vr::SharedRenderFrame render{};
            if (parent == nullptr && shared.read_render(render) && process_is_arma(render.source_pid)) {
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
