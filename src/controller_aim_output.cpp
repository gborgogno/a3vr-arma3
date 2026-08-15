#include "controller_aim_output.hpp"
#include "game_context.hpp"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iterator>
#include <string_view>
#include <windows.h>

namespace a3vr {
namespace {

constexpr float kPi = 3.14159265358979323846F;
constexpr float kMaximumFrameAngle = 0.20F;
constexpr float kCursorHorizontalFov = 70.0F * kPi / 180.0F;
constexpr float kCursorVerticalFov = 50.0F * kPi / 180.0F;
constexpr float kCursorSmoothing = 0.32F;

float wrap_angle(float value) noexcept {
    while (value > kPi) value -= 2.0F * kPi;
    while (value < -kPi) value += 2.0F * kPi;
    return value;
}

bool game_is_foreground(const std::uint32_t game_pid) noexcept {
    if (game_pid == 0) return false;
    const HWND foreground = GetForegroundWindow();
    if (foreground == nullptr) return false;
    DWORD foreground_pid{};
    GetWindowThreadProcessId(foreground, &foreground_pid);
    return foreground_pid == game_pid;
}

float dot(const Vec3 a, const Vec3 b) noexcept {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

void move_cursor_in_game_window(const std::uint32_t game_pid,
                                const float x, const float y) noexcept {
    const HWND window = GetForegroundWindow();
    if (window == nullptr) return;
    DWORD foreground_pid{};
    GetWindowThreadProcessId(window, &foreground_pid);
    if (foreground_pid != game_pid) return;
    RECT client{};
    if (!GetClientRect(window, &client)) return;
    POINT origin{client.left, client.top};
    if (!ClientToScreen(window, &origin)) return;
    const int width = (std::max)(1L, client.right - client.left);
    const int height = (std::max)(1L, client.bottom - client.top);
    SetCursorPos(origin.x + static_cast<int>(std::lround(x * (width - 1))),
                 origin.y + static_cast<int>(std::lround(y * (height - 1))));
}

} // namespace

ControllerAngles controller_angles_world(const TrackedPose& controller) noexcept {
    if (!controller.orientation_valid) return {};
    const Vec3 forward = rotate(
        controller.orientation, {0.0F, 0.0F, -1.0F});
    return {
        // OpenXR's horizontal controller rotation has the opposite sign to
        // Windows relative mouse X as Arma consumes it.
        std::atan2(forward.x, -forward.z),
        std::asin(std::clamp(forward.y, -1.0F, 1.0F)),
    };
}

ControllerCursorPosition controller_cursor_position(
    const TrackedPose& controller, const TrackedPose& head,
    const float horizontal_fov_radians,
    const float vertical_fov_radians) noexcept {
    if (!controller.orientation_valid || !head.orientation_valid ||
        horizontal_fov_radians <= 0.0F || vertical_fov_radians <= 0.0F) return {};
    const Vec3 controller_forward = rotate(controller.orientation, {0.0F, 0.0F, -1.0F});
    const Vec3 head_forward = rotate(head.orientation, {0.0F, 0.0F, -1.0F});
    const Vec3 head_right = rotate(head.orientation, {1.0F, 0.0F, 0.0F});
    const Vec3 head_up = rotate(head.orientation, {0.0F, 1.0F, 0.0F});
    const float forward = dot(controller_forward, head_forward);
    if (forward <= 0.05F) return {};
    const float yaw = std::atan2(dot(controller_forward, head_right), forward);
    const float pitch = std::atan2(dot(controller_forward, head_up), forward);
    return {
        true,
        std::clamp(0.5F + yaw / horizontal_fov_radians, 0.0F, 1.0F),
        std::clamp(0.5F - pitch / vertical_fov_radians, 0.0F, 1.0F),
    };
}

ControllerAimOutput::ControllerAimOutput() {
    char enabled_value[8]{};
    const DWORD enabled_size = GetEnvironmentVariableA(
        "A3VR_CONTROLLER_AIM", enabled_value,
        static_cast<DWORD>(std::size(enabled_value)));
    configured_ = true;
    enabled_ = enabled_size == 0 || std::string_view(enabled_value) == "1";

    char scale_value[32]{};
    const DWORD scale_size = GetEnvironmentVariableA(
        "A3VR_CONTROLLER_COUNTS_PER_RADIAN", scale_value,
        static_cast<DWORD>(std::size(scale_value)));
    if (scale_size > 0 && scale_size < std::size(scale_value)) {
        const float parsed = std::strtof(scale_value, nullptr);
        if (parsed >= 100.0F && parsed <= 5000.0F) counts_per_radian_ = parsed;
    }
}

void ControllerAimOutput::recenter() noexcept {
    previous_valid_ = false;
    previous_ = {};
    residual_x_ = 0.0F;
    residual_y_ = 0.0F;
}

void ControllerAimOutput::toggle() noexcept {
    if (!configured_) return;
    enabled_ = !enabled_;
    recenter();
}

void ControllerAimOutput::update(const TrackedPose& controller,
                                 const TrackedPose& head,
                                 const std::uint32_t game_pid,
                                 const bool recenter_requested) noexcept {
    const bool toggle_down = (GetAsyncKeyState(VK_F9) & 0x8000) != 0;
    if (toggle_down && !toggle_key_down_ && configured_) {
        toggle();
    }
    toggle_key_down_ = toggle_down;

    const bool cursor_toggle_down = (GetAsyncKeyState(VK_F10) & 0x8000) != 0;
    if (cursor_toggle_down && !cursor_toggle_key_down_) cursor_forced_ = !cursor_forced_;
    cursor_toggle_key_down_ = cursor_toggle_down;

    if (recenter_requested) recenter();
    if (!enabled_ || !controller.orientation_valid) {
        previous_valid_ = false;
        return;
    }

    if (!game_is_foreground(game_pid)) {
        previous_valid_ = false;
        cursor_mode_previous_ = false;
        return;
    }

    // Normal tracked motion is deliberately shared by gameplay and menus:
    // relative mouse input aims the weapon in-game and moves Arma's cursor in
    // an interface.  Consequently a stale/misreported UI state can never take
    // weapon motion away again. F10 remains an optional absolute laser-pointer
    // override for unusual third-party interfaces.
    const bool cursor_mode = cursor_forced_;
    if (cursor_mode) {
        const ControllerCursorPosition target = controller_cursor_position(
            controller, head, kCursorHorizontalFov, kCursorVerticalFov);
        if (target.valid) {
            if (!cursor_mode_previous_) {
                cursor_x_ = target.x;
                cursor_y_ = target.y;
            } else {
                cursor_x_ += (target.x - cursor_x_) * kCursorSmoothing;
                cursor_y_ += (target.y - cursor_y_) * kCursorSmoothing;
            }
            move_cursor_in_game_window(game_pid, cursor_x_, cursor_y_);
        }
        cursor_mode_previous_ = true;
        previous_valid_ = false;
        return;
    }
    cursor_mode_previous_ = false;

    // World-space controller deltas keep head rotation completely independent
    // from weapon aiming. Turning the headset must never inject mouse input.
    const ControllerAngles current = controller_angles_world(controller);
    if (!previous_valid_) {
        previous_ = current;
        previous_valid_ = true;
        return;
    }

    const float yaw_delta = std::clamp(
        wrap_angle(current.yaw - previous_.yaw),
        -kMaximumFrameAngle, kMaximumFrameAngle);
    const float pitch_delta = std::clamp(
        current.pitch - previous_.pitch,
        -kMaximumFrameAngle, kMaximumFrameAngle);
    previous_ = current;

    residual_x_ += yaw_delta * counts_per_radian_;
    residual_y_ += -pitch_delta * counts_per_radian_;
    const LONG dx = static_cast<LONG>(std::lround(residual_x_));
    const LONG dy = static_cast<LONG>(std::lround(residual_y_));
    residual_x_ -= static_cast<float>(dx);
    residual_y_ -= static_cast<float>(dy);
    if (dx == 0 && dy == 0) return;

    INPUT input{};
    input.type = INPUT_MOUSE;
    input.mi.dx = dx;
    input.mi.dy = dy;
    input.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_MOVE_NOCOALESCE;
    (void)SendInput(1, &input, sizeof(input));
}

} // namespace a3vr
