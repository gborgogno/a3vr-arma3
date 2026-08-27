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
    bool sprint_click{};
    bool reload{};
    bool fire_mode{};
    bool swap_weapon{};
    bool interact{};
    bool vault{};
    bool grenade{};
    bool radial_menu{};
};

struct MovementKeys {
    bool forward{};
    bool backward{};
    bool left{};
    bool right{};
};

struct WeaponAccessoryChords {
    bool light_or_laser{};
    bool deploy_weapon{};
    bool toggle_proxy{};
    bool inventory{};
    bool map{};
};

[[nodiscard]] MovementKeys movement_keys_from_stick(
    float x, float y, float threshold = 0.25F) noexcept;
[[nodiscard]] bool analog_button_pressed(
    float value, bool previous, float press_threshold,
    float release_threshold) noexcept;
[[nodiscard]] bool roomscale_crouch_state(
    float height_drop_metres, bool previous,
    float enter_threshold = 0.30F,
    float exit_threshold = 0.18F) noexcept;
[[nodiscard]] WeaponAccessoryChords weapon_accessory_chords(
    const ControllerInputState& state,
    bool gameplay_mode,
    bool vehicle_mode) noexcept;

class ControllerInputOutput final {
public:
    ControllerInputOutput();
    ~ControllerInputOutput();

    ControllerInputOutput(const ControllerInputOutput&) = delete;
    ControllerInputOutput& operator=(const ControllerInputOutput&) = delete;

    void update(const ControllerInputState& state, std::uint32_t game_pid) noexcept;
    void release_all() noexcept;
    [[nodiscard]] bool enabled() const noexcept { return enabled_; }
    [[nodiscard]] bool smooth_turn_enabled() const noexcept {
        return smooth_turn_enabled_;
    }

private:
    bool enabled_{};
    bool forward_{};
    bool backward_{};
    bool left_{};
    bool right_{};
    bool sprint_{};
    bool fire_{};
    bool aim_{};
    bool interact_{};
    bool reload_previous_{};
    bool fire_mode_previous_{};
    bool swap_previous_{};
    bool vault_previous_{};
    bool grenade_previous_{};
    bool radial_previous_{};
    bool light_or_laser_previous_{};
    bool deploy_weapon_previous_{};
    bool inventory_previous_{};
    bool map_previous_{};
    bool reload_chord_consumed_{};
    bool fire_mode_chord_consumed_{};
    bool grenade_chord_consumed_{};
    bool ui_accept_previous_{};
    bool ui_back_previous_{};
    bool ui_middle_previous_{};
    bool radial_context_active_{};
    bool smooth_turn_enabled_{};
    float stick_threshold_{0.25F};
    float smooth_turn_counts_per_second_{1800.0F};
    float vehicle_pitch_counts_per_second_{950.0F};
    float smooth_turn_residual_{};
    float vehicle_pitch_residual_{};
    std::chrono::steady_clock::time_point last_update_{};
    std::chrono::steady_clock::time_point last_ui_scroll_{};
};

} // namespace a3vr
