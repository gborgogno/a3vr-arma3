#include "controller_aim_output.hpp"

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

ControllerAimOutput::ControllerAimOutput() {
    char enabled_value[8]{};
    const DWORD enabled_size = GetEnvironmentVariableA(
        "A3VR_CONTROLLER_AIM", enabled_value,
        static_cast<DWORD>(std::size(enabled_value)));
    configured_ = enabled_size > 0;
    enabled_ = configured_ && std::string_view(enabled_value) == "1";

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
                                 const std::uint32_t game_pid,
                                 const bool recenter_requested) noexcept {
    const bool toggle_down = (GetAsyncKeyState(VK_F9) & 0x8000) != 0;
    if (toggle_down && !toggle_key_down_ && configured_) {
        toggle();
    }
    toggle_key_down_ = toggle_down;

    if (recenter_requested) recenter();
    if (!enabled_ || !controller.orientation_valid) {
        previous_valid_ = false;
        return;
    }

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

    if (!game_is_foreground(game_pid)) return;

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
