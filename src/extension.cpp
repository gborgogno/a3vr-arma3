#include "shared_state.hpp"
#include "d3d11_capture.hpp"
#include "game_context.hpp"

#include <algorithm>
#include <chrono>
#include <cstring>
#include <iomanip>
#include <mutex>
#include <sstream>
#include <string>
#include <string_view>
#include <thread>
#include <windows.h>

#ifndef A3VR_VERSION
#define A3VR_VERSION "dev"
#endif

namespace {

a3vr::SharedState& shared_state() {
    static a3vr::SharedState state;
    return state;
}

void copy_output(char* output, const unsigned int output_size, const std::string_view value) {
    if (output == nullptr || output_size == 0) return;
    const auto count = std::min<std::size_t>(value.size(), output_size - 1);
    std::memcpy(output, value.data(), count);
    output[count] = '\0';
}

void append_vec(std::ostringstream& stream, const a3vr::Vec3 value) {
    stream << '[' << value.x << ',' << value.y << ',' << value.z << ']';
}

void append_pose(std::ostringstream& stream, const a3vr::TrackedPose& pose) {
    stream << '[' << (pose.position_valid ? 1 : 0) << ','
           << (pose.orientation_valid ? 1 : 0) << ',';
    append_vec(stream, a3vr::xr_to_arma_position(pose.position));
    stream << ',';
    append_vec(stream, a3vr::arma_direction(pose.orientation));
    stream << ',';
    append_vec(stream, a3vr::arma_up(pose.orientation));
    stream << ']';
}

std::string pose_as_sqf(const a3vr::TrackingSnapshot& pose) {
    std::ostringstream stream;
    stream << std::setprecision(8) << '[' << pose.sequence << ','
           << pose.predicted_display_time << ',' << pose.session_state << ','
           << (pose.session_running ? 1 : 0) << ',';
    append_pose(stream, pose.head);
    stream << ',';
    append_pose(stream, pose.left_hand);
    stream << ',';
    append_pose(stream, pose.right_hand);
    stream << ",[[";
    for (std::size_t eye = 0; eye < pose.eyes.size(); ++eye) {
        if (eye != 0) stream << "],[";
        const auto& view = pose.eyes[eye];
        append_pose(stream, view.pose);
        stream << ",[" << view.fov[0] << ',' << view.fov[1] << ','
               << view.fov[2] << ',' << view.fov[3] << ']';
    }
    stream << "]],";
    stream << '[' << pose.controller_move_x << ',' << pose.controller_move_y << ','
           << pose.controller_buttons << ',' << pose.controller_turn_x << ','
           << pose.controller_turn_y << ']';
    stream << ",[";
    for (std::size_t finger = 0; finger < pose.left_finger_curls.size(); ++finger) {
        if (finger != 0) stream << ',';
        stream << pose.left_finger_curls[finger];
    }
    stream << ']';
    stream << ']';
    return stream.str();
}

bool launch_server() {
    static std::mutex launch_mutex;
    const std::scoped_lock lock(launch_mutex);
    if (HANDLE instance = OpenMutexW(
            SYNCHRONIZE, FALSE, L"Local\\A3VR_Server_Instance_v30")) {
        CloseHandle(instance);
        return true;
    }
    HMODULE module{};
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                            GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            reinterpret_cast<LPCWSTR>(&launch_server), &module)) return false;
    wchar_t module_path[MAX_PATH]{};
    if (GetModuleFileNameW(module, module_path, MAX_PATH) == 0) return false;
    std::wstring server_path(module_path);
    const auto separator = server_path.find_last_of(L"\\/");
    server_path.resize(separator + 1);
    const std::wstring runtime_config = server_path + L"a3vr-runtime.ini";
    wchar_t runtime_manifest[MAX_PATH]{};
    const DWORD runtime_length = GetPrivateProfileStringW(
        L"openxr", L"runtime", L"", runtime_manifest,
        static_cast<DWORD>(std::size(runtime_manifest)), runtime_config.c_str());
    server_path += L"A3VRRuntime_v30.exe";
    std::wstring command = L"\"" + server_path + L"\" --parent " +
                           std::to_wstring(GetCurrentProcessId());
    STARTUPINFOW startup{sizeof(startup)};
    PROCESS_INFORMATION process{};
    wchar_t previous_runtime[MAX_PATH]{};
    const DWORD previous_length = GetEnvironmentVariableW(
        L"XR_RUNTIME_JSON", previous_runtime,
        static_cast<DWORD>(std::size(previous_runtime)));
    const bool had_previous_runtime = previous_length > 0 &&
        previous_length < std::size(previous_runtime);
    const bool use_runtime_override = runtime_length > 0 &&
        runtime_length < std::size(runtime_manifest) &&
        GetFileAttributesW(runtime_manifest) != INVALID_FILE_ATTRIBUTES;
    if (use_runtime_override) {
        SetEnvironmentVariableW(L"XR_RUNTIME_JSON", runtime_manifest);
    }
    const BOOL created = CreateProcessW(server_path.c_str(), command.data(), nullptr, nullptr,
                                        FALSE, CREATE_NO_WINDOW, nullptr, nullptr,
                                        &startup, &process);
    if (use_runtime_override) {
        SetEnvironmentVariableW(L"XR_RUNTIME_JSON",
                                had_previous_runtime ? previous_runtime : nullptr);
    }
    if (created) {
        CloseHandle(process.hThread);
        CloseHandle(process.hProcess);
    }
    return created != FALSE;
}

bool read_state(a3vr::TrackingSnapshot& snapshot, std::string& status) {
    return shared_state().read(snapshot, status);
}

std::string dispatch(const std::string_view function) {
    if (function == "start") {
        if (!a3vr::start_d3d11_capture()) return a3vr::d3d11_capture_status();
        a3vr::TrackingSnapshot snapshot{};
        std::string status;
        if (read_state(snapshot, status)) return status;
        return launch_server() ? "starting" : "error: cannot launch A3VRRuntime_v30.exe";
    }
    if (function == "status") {
        a3vr::TrackingSnapshot snapshot{};
        std::string status;
        return read_state(snapshot, status) ? status : "stopped";
    }
    if (function == "capture") return a3vr::d3d11_capture_status();
    if (function.starts_with("context:")) {
        const auto value = function.substr(8);
        std::uint32_t flags{};
        const auto parse_flag = [&](const std::string_view name,
                                    const std::uint32_t flag) {
            if (value.find(name) != std::string_view::npos) flags |= flag;
        };
        parse_flag("ui", a3vr::game_context_ui);
        parse_flag("zeus", a3vr::game_context_zeus);
        parse_flag("vehicle", a3vr::game_context_vehicle);
        a3vr::set_game_context(flags);
        return "ok";
    }
    if (function == "render") {
        a3vr::SharedRenderFrame frame{};
        if (!shared_state().read_render(frame)) return "render IPC unavailable";
        std::ostringstream stream;
        stream << "state=" << frame.capture_state << ",hr=0x" << std::hex
               << static_cast<std::uint32_t>(frame.last_hresult) << std::dec
               << ",frames=" << frame.frame_sequence << ",size="
               << frame.width << 'x' << frame.height << ",format=" << frame.dxgi_format
               << ",handle=" << frame.shared_handle;
        return stream.str();
    }
    if (function == "pose") {
        a3vr::TrackingSnapshot snapshot{};
        std::string status;
        return read_state(snapshot, status) ? pose_as_sqf(snapshot) : "[]";
    }
    if (function == "probe") {
        for (int attempt = 0; attempt < 200; ++attempt) {
            a3vr::TrackingSnapshot snapshot{};
            std::string status;
            if (read_state(snapshot, status) &&
                (snapshot.sequence > 0 || status.starts_with("error:"))) {
                return status + "|" + pose_as_sqf(snapshot);
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(25));
        }
        return "timeout|[]";
    }
    if (function == "stop") return "server follows host lifetime";
    if (function == "version") return A3VR_VERSION;
    return "error: unknown command";
}

} // namespace

extern "C" {
__declspec(dllexport) void __stdcall RVExtensionVersion(char* output, unsigned int output_size) {
    copy_output(output, output_size, A3VR_VERSION);
}
__declspec(dllexport) void __stdcall RVExtension(char* output, unsigned int output_size, const char* function) {
    try { copy_output(output, output_size, dispatch(function != nullptr ? function : "")); }
    catch (...) { copy_output(output, output_size, "error: unhandled native exception"); }
}
__declspec(dllexport) int __stdcall RVExtensionArgs(char* output, unsigned int output_size,
    const char* function, const char**, unsigned int) {
    RVExtension(output, output_size, function);
    return 0;
}
}

namespace {
DWORD WINAPI start_capture_after_load(void*) {
    // DllMain itself runs under the loader lock. Install the DXGI hooks from a
    // worker only after LoadLibrary has completed so logo/menu frames can be
    // captured safely when the launcher preloads this extension.
    (void)a3vr::start_d3d11_capture();
    return 0;
}
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(instance);
        if (HANDLE worker = CreateThread(nullptr, 0, start_capture_after_load,
                                         nullptr, 0, nullptr)) {
            CloseHandle(worker);
        }
    }
    return TRUE;
}
