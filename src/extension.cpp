#include "shared_state.hpp"
#include "d3d11_capture.hpp"
#include "game_context.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
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
    stream << ",[" << static_cast<std::uint32_t>(pose.motion_aim_mode) << ',';
    append_pose(stream, pose.weapon_target.room_pose);
    stream << ',';
    append_pose(stream, pose.weapon_target.player_pose);
    stream << ',';
    append_vec(stream, a3vr::xr_to_arma_position(
        pose.weapon_target.muzzle_origin));
    stream << ',';
    append_vec(stream, a3vr::xr_to_arma_position(
        pose.weapon_target.muzzle_direction));
    stream << ']';
    stream << ']';
    return stream.str();
}

bool launch_server() {
    static std::mutex launch_mutex;
    const std::scoped_lock lock(launch_mutex);
    if (HANDLE instance = OpenMutexW(
            SYNCHRONIZE, FALSE, L"Local\\A3VR_Server_Instance_v31")) {
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
    server_path += L"A3VRRuntime_v31.exe";
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
        return launch_server() ? "starting" : "error: cannot launch A3VRRuntime_v31.exe";
    }
    if (function == "status") {
        a3vr::TrackingSnapshot snapshot{};
        std::string status;
        return read_state(snapshot, status) ? status : "stopped";
    }
    if (function == "capture") return a3vr::d3d11_capture_status();
    if (function.starts_with("aim_feedback:")) {
        a3vr::AimFeedback feedback{};
        const std::string payload(function.substr(13));
        if (payload == "invalid") {
            return shared_state().publish_aim_feedback(feedback) ? "ok" : "unavailable";
        }
        float x{};
        float y{};
        float z{};
        if (sscanf_s(payload.c_str(), "%f,%f,%f", &x, &y, &z) != 3 ||
            !std::isfinite(x) || !std::isfinite(y) || !std::isfinite(z) ||
            x * x + y * y + z * z < 0.25F) {
            return "error: invalid aim feedback";
        }
        feedback.valid = true;
        feedback.weapon_direction = {x, y, z};
        return shared_state().publish_aim_feedback(feedback) ? "ok" : "unavailable";
    }
    if (function.starts_with("haptic:")) {
        a3vr::HapticRequest request{};
        const auto effect = function.substr(7);
        if (effect == "shot") {
            request = {0, 0.42F, 120.0F, 55, 2U};
        } else if (effect == "damage") {
            request = {0, 0.72F, 70.0F, 160, 3U};
        } else if (effect == "explosion") {
            request = {0, 1.0F, 45.0F, 360, 3U};
        } else {
            return "error: invalid haptic effect";
        }
        return shared_state().publish_haptic(request) ? "ok" : "unavailable";
    }
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
        parse_flag("gameplay", a3vr::game_context_gameplay);
        parse_flag("mouse", a3vr::game_context_mouse_ui);
        a3vr::set_game_context(flags);
        return "ok";
    }
    if (function.starts_with("settings:")) {
        const std::string_view setting = function.substr(9);
        const auto set_option = [](const std::size_t index,
                                   const bool enabled) {
            a3vr::set_game_context_flag(index, enabled);
        };
        if (setting == "aim=right" || setting == "aim=controller") {
            set_option(4, false);
        } else if (setting == "aim=left") set_option(4, true);
        else if (setting == "pointer=controller") set_option(5, false);
        else if (setting == "pointer=head") set_option(5, true);
        else if (setting == "turn=normal") {
            set_option(6, false);
            set_option(7, false);
        } else if (setting == "turn=fast") {
            set_option(6, true);
            set_option(7, false);
        } else if (setting == "turn=comfort") {
            set_option(6, false);
            set_option(7, true);
        } else if (setting == "ui=full") set_option(8, false);
        else if (setting == "ui=large") set_option(8, true);
        else if (setting == "movement=body") set_option(9, false);
        else if (setting == "movement=head") set_option(9, true);
        else if (setting == "optic=off") set_option(12, false);
        else if (setting == "optic=grip") set_option(12, true);
        else if (setting == "motion=off") set_option(13, false);
        else if (setting == "motion=on") set_option(13, true);
        else return "error: invalid setting";
        return "ok";
    }
    if (function == "proxy_mode:on") {
        a3vr::set_game_context_flag(11, true);
        return "ok";
    }
    if (function == "proxy_mode:off") {
        a3vr::set_game_context_flag(11, false);
        return "ok";
    }
    if (function == "settings") {
        const std::uint32_t flags = a3vr::game_context();
        std::ostringstream stream;
        stream << "aim=" << ((flags & a3vr::game_option_aim_left) != 0U
            ? "left" : "right")
               << ",pointer=" << ((flags & a3vr::game_option_pointer_head) != 0U
            ? "head" : "controller")
               << ",turn=" << ((flags & a3vr::game_option_turn_fast) != 0U
            ? "fast" : ((flags & a3vr::game_option_turn_slow) != 0U
                ? "comfort" : "normal"))
               << ",ui=" << ((flags & a3vr::game_option_ui_large) != 0U
            ? "large" : "full")
               << ",movement=" << ((flags & a3vr::game_option_movement_head) != 0U
            ? "head" : "body")
               << ",optic=" << ((flags & a3vr::game_option_native_ads) != 0U
            ? "grip" : "off")
               << ",motion=" << ((flags & a3vr::game_option_motion_aim) != 0U
            ? "on" : "off");
        return stream.str();
    }
    if (function == "recenter") {
        a3vr::request_recenter();
        return "ok";
    }
    if (function.starts_with("body_yaw:")) {
        const std::string payload(function.substr(9));
        float degrees{};
        if (sscanf_s(payload.c_str(), "%f", &degrees) != 1 ||
            !std::isfinite(degrees) || std::abs(degrees) > 20.0F) {
            return "error: invalid body yaw";
        }
        a3vr::request_body_yaw_transfer(degrees);
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
    if (function == "motion_mode") {
        a3vr::TrackingSnapshot snapshot{};
        std::string status;
        if (!read_state(snapshot, status)) return "unavailable";
        return snapshot.motion_aim_mode == a3vr::MotionAimMode::absolute_weapon
            ? "AbsoluteWeapon" : "LegacyRelative";
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
    // Until the addon can report an actual gameplay context, frame the logo,
    // loading screens and launcher menus as complete UI surfaces.
    a3vr::set_game_context(
        a3vr::game_context_ui | a3vr::game_context_mouse_ui);
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
