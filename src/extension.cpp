#include "shared_state.hpp"
#include "d3d11_capture.hpp"

#include <algorithm>
#include <chrono>
#include <cstring>
#include <iomanip>
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
           << pose.controller_buttons << ']';
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
    HMODULE module{};
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                            GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            reinterpret_cast<LPCWSTR>(&launch_server), &module)) return false;
    wchar_t module_path[MAX_PATH]{};
    if (GetModuleFileNameW(module, module_path, MAX_PATH) == 0) return false;
    std::wstring server_path(module_path);
    const auto separator = server_path.find_last_of(L"\\/");
    server_path.resize(separator + 1);
    server_path += L"A3VRRuntime_v25.exe";
    std::wstring command = L"\"" + server_path + L"\" --parent " +
                           std::to_wstring(GetCurrentProcessId());
    STARTUPINFOW startup{sizeof(startup)};
    PROCESS_INFORMATION process{};
    const BOOL created = CreateProcessW(server_path.c_str(), command.data(), nullptr, nullptr,
                                        FALSE, CREATE_NO_WINDOW, nullptr, nullptr,
                                        &startup, &process);
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
        return launch_server() ? "starting" : "error: cannot launch A3VRRuntime_v25.exe";
    }
    if (function == "status") {
        a3vr::TrackingSnapshot snapshot{};
        std::string status;
        return read_state(snapshot, status) ? status : "stopped";
    }
    if (function == "capture") return a3vr::d3d11_capture_status();
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
