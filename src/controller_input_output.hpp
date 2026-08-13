#pragma once

#include <chrono>
#include <cstdint>

namespace a3vr {

struct ControllerInputState {
    float move_x{};
    float move_y{};
    float turn_x{};
    float turn_y{};
    bool fire{};
    bool aim{};
    bool sprint{};
    bool reload{};
    bool fire_mode{};
    bool swap_weapon{};
    bool interact{};
    bool vault{};
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
    bool proxy_weapon_actions_{};
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
    bool vault_previous_{};
    bool stand_previous_{};
    bool crouch_previous_{};
    bool sidearm_selected_{};
    bool smooth_turn_enabled_{};
    float stick_threshold_{0.25F};
    float smooth_turn_counts_per_second_{300.0F};
    float smooth_turn_residual_{};
    std::chrono::steady_clock::time_point last_update_{};
};

} // namespace a3vr
