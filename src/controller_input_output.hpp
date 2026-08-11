#pragma once

#include <cstdint>

namespace a3vr {

struct ControllerInputState {
    float move_x{};
    float move_y{};
    bool fire{};
    bool aim{};
    bool sprint{};
    bool reload{};
    bool fire_mode{};
    bool swap_weapon{};
    bool interact{};
    bool motion_toggle{};
};

struct MovementKeys {
    bool forward{};
    bool backward{};
    bool left{};
    bool right{};
};

[[nodiscard]] MovementKeys movement_keys_from_stick(
    float x, float y, float threshold = 0.25F) noexcept;

class ControllerInputOutput final {
public:
    ControllerInputOutput();
    ~ControllerInputOutput();

    ControllerInputOutput(const ControllerInputOutput&) = delete;
    ControllerInputOutput& operator=(const ControllerInputOutput&) = delete;

    void update(const ControllerInputState& state, std::uint32_t game_pid) noexcept;
    void release_all() noexcept;

private:
    bool enabled_{};
    bool forward_{};
    bool backward_{};
    bool left_{};
    bool right_{};
    bool sprint_{};
    bool fire_{};
    bool aim_{};
    bool reload_previous_{};
    bool fire_mode_previous_{};
    bool swap_previous_{};
    bool interact_previous_{};
    bool sidearm_selected_{};
    float stick_threshold_{0.25F};
};

} // namespace a3vr
