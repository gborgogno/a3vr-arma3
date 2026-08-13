#pragma once

#include "pose.hpp"

#include <cstdint>

namespace a3vr {

struct ControllerAngles {
    float yaw{};
    float pitch{};
};

ControllerAngles controller_angles_world(const TrackedPose& controller) noexcept;

struct ControllerCursorPosition {
    bool valid{};
    float x{0.5F};
    float y{0.5F};
};

ControllerCursorPosition controller_cursor_position(
    const TrackedPose& controller, const TrackedPose& head,
    float horizontal_fov_radians, float vertical_fov_radians) noexcept;

class ControllerAimOutput final {
public:
    ControllerAimOutput();

    void recenter() noexcept;
    void toggle() noexcept;
    void update(const TrackedPose& controller, const TrackedPose& head,
                std::uint32_t game_pid,
                bool recenter_requested) noexcept;
    [[nodiscard]] bool enabled() const noexcept { return enabled_; }

private:
    bool configured_{};
    bool enabled_{};
    bool previous_valid_{};
    bool toggle_key_down_{};
    bool cursor_toggle_key_down_{};
    bool cursor_forced_{};
    bool cursor_mode_previous_{};
    ControllerAngles previous_{};
    float residual_x_{};
    float residual_y_{};
    float counts_per_radian_{420.0F};
    float cursor_x_{0.5F};
    float cursor_y_{0.5F};
};

} // namespace a3vr
