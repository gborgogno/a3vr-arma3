#pragma once

#include "pose.hpp"

#include <cstdint>

namespace a3vr {

struct ControllerAngles {
    float yaw{};
    float pitch{};
};

ControllerAngles controller_angles_world(const TrackedPose& controller) noexcept;
ControllerAngles arma_direction_angles(Vec3 direction) noexcept;

struct AimServoCorrection {
    bool valid{};
    float yaw{};
    float pitch{};
};

AimServoCorrection absolute_aim_correction(
    ControllerAngles controller, Vec3 weapon_direction,
    ControllerAngles calibration) noexcept;

struct ControllerCursorPosition {
    bool valid{};
    float x{0.5F};
    float y{0.5F};
};

ControllerCursorPosition controller_cursor_position(
    const TrackedPose& controller, const TrackedPose& head,
    float horizontal_fov_radians, float vertical_fov_radians) noexcept;
ControllerCursorPosition head_cursor_position(
    const TrackedPose& head, const TrackedPose& reference,
    float horizontal_fov_radians, float vertical_fov_radians) noexcept;

class ControllerAimOutput final {
public:
    ControllerAimOutput();

    void recenter() noexcept;
    void toggle() noexcept;
    void configure_absolute_servo(float counts_per_radian,
                                  float gain,
                                  float max_counts) noexcept;
    void update(const TrackedPose& controller, const TrackedPose& head,
                std::uint32_t game_pid,
                bool recenter_requested,
                bool pointer_only,
                bool absolute_servo,
                const AimFeedback& aim_feedback,
                bool smooth_turn_active) noexcept;
    void suspend() noexcept { recenter(); }
    [[nodiscard]] bool enabled() const noexcept { return enabled_; }

private:
    bool configured_{};
    bool enabled_{};
    bool previous_valid_{};
    bool cursor_mode_previous_{};
    bool head_pointer_previous_{};
    bool cursor_head_reference_valid_{};
    TrackedPose cursor_head_reference_{};
    ControllerAngles previous_{};
    float residual_x_{};
    float residual_y_{};
    // Higher default keeps the native weapon/body response close to the
    // physical controller instead of requiring exaggerated wrist movement.
    float counts_per_radian_{900.0F};
    float servo_counts_per_radian_{2100.0F};
    float servo_gain_{0.42F};
    float servo_max_counts_{160.0F};
    bool servo_reference_valid_{};
    ControllerAngles servo_calibration_{};
    std::uint64_t servo_feedback_sequence_{};
    float cursor_x_{0.5F};
    float cursor_y_{0.5F};
};

} // namespace a3vr
