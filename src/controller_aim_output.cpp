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
constexpr float kServoDeadzone = 0.0015F;

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

ControllerAngles arma_direction_angles(Vec3 direction) noexcept {
    const float magnitude = std::sqrt(
        direction.x * direction.x + direction.y * direction.y +
        direction.z * direction.z);
    if (!std::isfinite(magnitude) || magnitude < 0.5F) return {};
    direction.x /= magnitude;
    direction.y /= magnitude;
    direction.z /= magnitude;
    return {
        std::atan2(direction.x, direction.y),
        std::asin(std::clamp(direction.z, -1.0F, 1.0F)),
    };
}

AimServoCorrection absolute_aim_correction(
    const ControllerAngles controller, const Vec3 weapon_direction,
    const ControllerAngles calibration) noexcept {
    const float magnitude_squared =
        weapon_direction.x * weapon_direction.x +
        weapon_direction.y * weapon_direction.y +
        weapon_direction.z * weapon_direction.z;
    if (!std::isfinite(magnitude_squared) || magnitude_squared < 0.25F) return {};
    const ControllerAngles weapon = arma_direction_angles(weapon_direction);
    return {
        true,
        wrap_angle(controller.yaw + calibration.yaw - weapon.yaw),
        std::clamp(controller.pitch + calibration.pitch - weapon.pitch,
                   -kMaximumFrameAngle * 3.0F,
                   kMaximumFrameAngle * 3.0F),
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

ControllerCursorPosition head_cursor_position(
    const TrackedPose& head, const TrackedPose& reference,
    const float horizontal_fov_radians,
    const float vertical_fov_radians) noexcept {
    // The comfort surface stays head locked. Compare the current HMD pose to
    // the pose captured when UI mode began to obtain a stable gaze cursor.
    return controller_cursor_position(
        head, reference, horizontal_fov_radians, vertical_fov_radians);
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


    char servo_gain_value[32]{};
    const DWORD servo_gain_size = GetEnvironmentVariableA(
        "A3VR_CONTROLLER_SERVO_GAIN", servo_gain_value,
        static_cast<DWORD>(std::size(servo_gain_value)));
    if (servo_gain_size > 0 && servo_gain_size < std::size(servo_gain_value)) {
        const float parsed = std::strtof(servo_gain_value, nullptr);
        if (parsed >= 0.05F && parsed <= 1.0F) servo_gain_ = parsed;
    }

    char servo_max_value[32]{};
    const DWORD servo_max_size = GetEnvironmentVariableA(
        "A3VR_CONTROLLER_SERVO_MAX_COUNTS", servo_max_value,
        static_cast<DWORD>(std::size(servo_max_value)));
    if (servo_max_size > 0 && servo_max_size < std::size(servo_max_value)) {
        const float parsed = std::strtof(servo_max_value, nullptr);
        if (parsed >= 20.0F && parsed <= 500.0F) servo_max_counts_ = parsed;
    }
}

void ControllerAimOutput::recenter() noexcept {
    previous_valid_ = false;
    previous_ = {};
    residual_x_ = 0.0F;
    residual_y_ = 0.0F;
    servo_reference_valid_ = false;
    servo_feedback_sequence_ = 0;
    cursor_head_reference_valid_ = false;
    cursor_head_reference_ = {};
}

void ControllerAimOutput::toggle() noexcept {
    if (!configured_) return;
    enabled_ = !enabled_;
    recenter();
}

void ControllerAimOutput::configure_absolute_servo(
    const float counts_per_radian, const float gain,
    const float max_counts) noexcept {
    servo_counts_per_radian_ = std::clamp(counts_per_radian, 100.0F, 5000.0F);
    servo_gain_ = std::clamp(gain, 0.05F, 1.0F);
    servo_max_counts_ = std::clamp(max_counts, 20.0F, 500.0F);
    recenter();
}

void ControllerAimOutput::update(const TrackedPose& controller,
                                 const TrackedPose& head,
                                 const std::uint32_t game_pid,
                                 const bool recenter_requested,
                                 const bool pointer_only,
                                 const bool absolute_servo,
                                 const AimFeedback& aim_feedback,
                                 const bool smooth_turn_active) noexcept {
    if (recenter_requested) recenter();
    if (!enabled_ ||
        (game_context() & game_option_motion_aim) == 0U) {
        previous_valid_ = false;
        servo_reference_valid_ = false;
        return;
    }

    if (!game_is_foreground(game_pid)) {
        previous_valid_ = false;
        servo_reference_valid_ = false;
        cursor_mode_previous_ = false;
        return;
    }

    // UI context owns the absolute pointer automatically. Gameplay context
    // forces it out, so no keyboard toggle can leak cursor movement into aim.
    const bool cursor_mode = pointer_only;
    if (cursor_mode) {
        const bool head_pointer =
            (game_context() & game_option_pointer_head) != 0U;
        ControllerCursorPosition target{};
        if (head_pointer && head.orientation_valid) {
            if (!cursor_mode_previous_ || !head_pointer_previous_ ||
                !cursor_head_reference_valid_) {
                cursor_head_reference_ = head;
                cursor_head_reference_valid_ = true;
                cursor_x_ = cursor_y_ = 0.5F;
            }
            target = head_cursor_position(
                head, cursor_head_reference_,
                kCursorHorizontalFov, kCursorVerticalFov);
        } else if (!head_pointer && controller.orientation_valid) {
            cursor_head_reference_valid_ = false;
            target = controller_cursor_position(
                controller, head, kCursorHorizontalFov, kCursorVerticalFov);
        }
        if (target.valid) {
            if (!cursor_mode_previous_ ||
                head_pointer != head_pointer_previous_) {
                cursor_x_ = target.x;
                cursor_y_ = target.y;
            } else {
                cursor_x_ += (target.x - cursor_x_) * kCursorSmoothing;
                cursor_y_ += (target.y - cursor_y_) * kCursorSmoothing;
            }
            move_cursor_in_game_window(game_pid, cursor_x_, cursor_y_);
        }
        cursor_mode_previous_ = true;
        head_pointer_previous_ = head_pointer;
        previous_valid_ = false;
        servo_reference_valid_ = false;
        return;
    }
    cursor_mode_previous_ = false;
    cursor_head_reference_valid_ = false;

    if (!controller.orientation_valid) {
        previous_valid_ = false;
        servo_reference_valid_ = false;
        return;
    }

    if (absolute_servo) {
        previous_valid_ = false;
        // Smooth turn deliberately changes the game's world heading. Re-anchor
        // only while the stick is held, then lock the controller back to the
        // real weapon direction on the first released frame.
        if (smooth_turn_active || !aim_feedback.valid) {
            servo_reference_valid_ = false;
            servo_feedback_sequence_ = aim_feedback.sequence;
            return;
        }
        // SQF feedback arrives at roughly 100 Hz. Applying the same stale
        // correction more than once would turn latency into oscillation.
        if (aim_feedback.sequence == servo_feedback_sequence_) return;
        servo_feedback_sequence_ = aim_feedback.sequence;

        const ControllerAngles controller_angles =
            controller_angles_world(controller);
        const ControllerAngles weapon_angles =
            arma_direction_angles(aim_feedback.weapon_direction);
        if (!servo_reference_valid_) {
            servo_calibration_.yaw = wrap_angle(
                weapon_angles.yaw - controller_angles.yaw);
            servo_calibration_.pitch =
                weapon_angles.pitch - controller_angles.pitch;
            servo_reference_valid_ = true;
            residual_x_ = residual_y_ = 0.0F;
            return;
        }

        const AimServoCorrection correction = absolute_aim_correction(
            controller_angles, aim_feedback.weapon_direction,
            servo_calibration_);
        if (!correction.valid) {
            servo_reference_valid_ = false;
            return;
        }
        const float yaw_error = std::abs(correction.yaw) >= kServoDeadzone
            ? correction.yaw : 0.0F;
        const float pitch_error = std::abs(correction.pitch) >= kServoDeadzone
            ? correction.pitch : 0.0F;
        residual_x_ += yaw_error * servo_counts_per_radian_ * servo_gain_;
        residual_y_ += -pitch_error * servo_counts_per_radian_ * servo_gain_;
        residual_x_ = std::clamp(
            residual_x_, -servo_max_counts_, servo_max_counts_);
        residual_y_ = std::clamp(
            residual_y_, -servo_max_counts_, servo_max_counts_);
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
        return;
    }
    servo_reference_valid_ = false;

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
