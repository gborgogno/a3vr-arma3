#pragma once

#include "pose.hpp"

#include <cstdint>

namespace a3vr {

struct ControllerAngles {
    float yaw{};
    float pitch{};
};

ControllerAngles controller_angles_world(const TrackedPose& controller) noexcept;

class ControllerAimOutput final {
public:
    ControllerAimOutput();

    void recenter() noexcept;
    void toggle() noexcept;
    void update(const TrackedPose& controller, std::uint32_t game_pid,
                bool recenter_requested) noexcept;
    [[nodiscard]] bool enabled() const noexcept { return enabled_; }

private:
    bool configured_{};
    bool enabled_{};
    bool previous_valid_{};
    bool toggle_key_down_{};
    ControllerAngles previous_{};
    float residual_x_{};
    float residual_y_{};
    float counts_per_radian_{900.0F};
};

} // namespace a3vr
