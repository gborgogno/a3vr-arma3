#include "controller_input_output.hpp"
#include "game_context.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <iterator>
#include <string_view>
#include <windows.h>

namespace a3vr {
namespace {

bool game_is_foreground(const std::uint32_t game_pid) noexcept {
    if (game_pid == 0) return false;
    const HWND foreground = GetForegroundWindow();
    if (foreground == nullptr) return false;
    DWORD foreground_pid{};
    GetWindowThreadProcessId(foreground, &foreground_pid);
    return foreground_pid == game_pid;
}

void set_key(const WORD key, const bool requested, bool& held) noexcept {
    if (requested == held) return;
    INPUT input{};
    input.type = INPUT_KEYBOARD;
    input.ki.wScan = static_cast<WORD>(MapVirtualKeyW(key, MAPVK_VK_TO_VSC));
    input.ki.dwFlags = KEYEVENTF_SCANCODE |
        (requested ? 0U : KEYEVENTF_KEYUP);
    if (SendInput(1, &input, sizeof(input)) == 1) held = requested;
}

void set_mouse_button(const DWORD down_flag, const DWORD up_flag,
                      const bool requested, bool& held) noexcept {
    if (requested == held) return;
    INPUT input{};
    input.type = INPUT_MOUSE;
    input.mi.dwFlags = requested ? down_flag : up_flag;
    if (SendInput(1, &input, sizeof(input)) == 1) held = requested;
}

void tap_key(const WORD key) noexcept {
    INPUT inputs[2]{};
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wScan = static_cast<WORD>(MapVirtualKeyW(key, MAPVK_VK_TO_VSC));
    inputs[0].ki.dwFlags = KEYEVENTF_SCANCODE;
    inputs[1] = inputs[0];
    inputs[1].ki.dwFlags = KEYEVENTF_SCANCODE | KEYEVENTF_KEYUP;
    (void)SendInput(2, inputs, sizeof(INPUT));
}

void tap_on_rising_edge(const bool current, bool& previous, const WORD key) noexcept {
    if (current && !previous) tap_key(key);
    previous = current;
}

void scroll_mouse(const LONG amount) noexcept {
    INPUT input{};
    input.type = INPUT_MOUSE;
    input.mi.mouseData = static_cast<DWORD>(amount);
    input.mi.dwFlags = MOUSEEVENTF_WHEEL;
    (void)SendInput(1, &input, sizeof(input));
}

} // namespace

MovementKeys movement_keys_from_stick(
    const float x, const float y, const float threshold) noexcept {
    const float deadzone = std::clamp(threshold, 0.1F, 0.9F);
    return {
        y > deadzone,
        y < -deadzone,
        x < -deadzone,
        x > deadzone,
    };
}

bool analog_button_pressed(const float value, const bool previous,
                           const float press_threshold,
                           const float release_threshold) noexcept {
    return previous ? value > release_threshold : value >= press_threshold;
}

bool roomscale_crouch_state(const float height_drop_metres,
                            const bool previous,
                            const float enter_threshold,
                            const float exit_threshold) noexcept {
    if (!std::isfinite(height_drop_metres) ||
        !std::isfinite(enter_threshold) || !std::isfinite(exit_threshold)) {
        return false;
    }
    const float enter = std::clamp(enter_threshold, 0.10F, 1.00F);
    const float exit = std::clamp(exit_threshold, 0.02F, enter - 0.02F);
    return previous ? height_drop_metres > exit : height_drop_metres >= enter;
}

ControllerInputOutput::ControllerInputOutput() {
    char enabled_value[8]{};
    const DWORD enabled_size = GetEnvironmentVariableA(
        "A3VR_CONTROLLER_BUTTONS", enabled_value,
        static_cast<DWORD>(std::size(enabled_value)));
    enabled_ = enabled_size == 0 || std::string_view(enabled_value) == "1";

    char proxy_value[8]{};
    const DWORD proxy_size = GetEnvironmentVariableA(
        "A3VR_PROXY_WEAPON", proxy_value,
        static_cast<DWORD>(std::size(proxy_value)));
    proxy_weapon_actions_ = proxy_size > 0 && std::string_view(proxy_value) == "1";

    char threshold_value[32]{};
    const DWORD threshold_size = GetEnvironmentVariableA(
        "A3VR_CONTROLLER_STICK_THRESHOLD", threshold_value,
        static_cast<DWORD>(std::size(threshold_value)));
    if (threshold_size > 0 && threshold_size < std::size(threshold_value)) {
        const float parsed = std::strtof(threshold_value, nullptr);
        if (parsed >= 0.1F && parsed <= 0.9F) stick_threshold_ = parsed;
    }

    char smooth_turn_value[8]{};
    const DWORD smooth_turn_size = GetEnvironmentVariableA(
        "A3VR_SMOOTH_TURN", smooth_turn_value,
        static_cast<DWORD>(std::size(smooth_turn_value)));
    smooth_turn_enabled_ = smooth_turn_size == 0 ||
        std::string_view(smooth_turn_value) == "1";

    char turn_rate_value[32]{};
    const DWORD turn_rate_size = GetEnvironmentVariableA(
        "A3VR_SMOOTH_TURN_COUNTS_PER_SECOND", turn_rate_value,
        static_cast<DWORD>(std::size(turn_rate_value)));
    if (turn_rate_size > 0 && turn_rate_size < std::size(turn_rate_value)) {
        const float parsed = std::strtof(turn_rate_value, nullptr);
        if (parsed >= 50.0F && parsed <= 2000.0F) smooth_turn_counts_per_second_ = parsed;
    }

    char vehicle_pitch_value[32]{};
    const DWORD vehicle_pitch_size = GetEnvironmentVariableA(
        "A3VR_VEHICLE_PITCH_COUNTS_PER_SECOND", vehicle_pitch_value,
        static_cast<DWORD>(std::size(vehicle_pitch_value)));
    if (vehicle_pitch_size > 0 && vehicle_pitch_size < std::size(vehicle_pitch_value)) {
        const float parsed = std::strtof(vehicle_pitch_value, nullptr);
        if (parsed >= 50.0F && parsed <= 2000.0F) {
            vehicle_pitch_counts_per_second_ = parsed;
        }
    }
}

ControllerInputOutput::~ControllerInputOutput() { release_all(); }

void ControllerInputOutput::release_all() noexcept {
    set_key('W', false, forward_);
    set_key('S', false, backward_);
    set_key('A', false, left_);
    set_key('D', false, right_);
    set_key(VK_LSHIFT, false, sprint_);
    set_mouse_button(MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, false, fire_);
    set_mouse_button(MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP, false, aim_);
    set_key(VK_SPACE, false, interact_);
    smooth_turn_residual_ = 0.0F;
    vehicle_pitch_residual_ = 0.0F;
    last_update_ = {};
    radial_context_active_ = false;
    set_game_context_flag(3, false);
}

void ControllerInputOutput::update(
    const ControllerInputState& state, const std::uint32_t game_pid) noexcept {
    if (!enabled_ || !game_is_foreground(game_pid)) {
        release_all();
        reload_previous_ = state.reload;
        fire_mode_previous_ = state.fire_mode;
        swap_previous_ = state.swap_weapon;
        vault_previous_ = state.vault;
        grenade_previous_ = state.grenade;
        radial_previous_ = state.radial_menu;
        return;
    }

    const auto now = std::chrono::steady_clock::now();
    float delta_seconds{};
    if (last_update_.time_since_epoch().count() != 0) {
        delta_seconds = std::clamp(
            std::chrono::duration<float>(now - last_update_).count(), 0.0F, 0.05F);
    }
    last_update_ = now;

    const std::uint32_t context = game_context();
    // Arma can leave the Windows cursor flagged as visible while gameplay has
    // exclusive input.  Only the addon-reported UI context is authoritative;
    // otherwise the runtime can accidentally disable every gameplay binding.
    const bool ui_mode = (context & game_context_ui) != 0U;
    const bool vehicle_mode = (context & game_context_vehicle) != 0U;
    // Never let a stale menu/cursor flag disable locomotion.  Arma and several
    // radial-menu mods keep UI displays alive while gameplay already resumed.
    const MovementKeys movement = movement_keys_from_stick(
        state.move_x, state.move_y, stick_threshold_);
    set_key('W', movement.forward, forward_);
    set_key('S', movement.backward, backward_);
    set_key('A', movement.left, left_);
    set_key('D', movement.right, right_);
    set_key(VK_LSHIFT, state.sprint && (movement.forward ||
        movement.backward || movement.left || movement.right), sprint_);
    // Keep native fire available for the magnified-optic fallback, where the
    // script camera is temporarily released. In proxy view SQF handles the
    // same trigger because Arma ignores this mouse event there.
    set_mouse_button(MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP,
                     state.fire, fire_);
    set_mouse_button(MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP,
                     state.aim, aim_);

    if (smooth_turn_enabled_ && delta_seconds > 0.0F) {
        const float magnitude = std::abs(state.turn_x);
        if (magnitude > stick_threshold_) {
            const float normalized = std::copysign(
                (magnitude - stick_threshold_) / (1.0F - stick_threshold_), state.turn_x);
            smooth_turn_residual_ += normalized * smooth_turn_counts_per_second_ * delta_seconds;
            const LONG dx = static_cast<LONG>(std::lround(smooth_turn_residual_));
            smooth_turn_residual_ -= static_cast<float>(dx);
            if (dx != 0) {
                INPUT input{};
                input.type = INPUT_MOUSE;
                input.mi.dx = dx;
                input.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_MOVE_NOCOALESCE;
                (void)SendInput(1, &input, sizeof(input));
            }
        } else {
            smooth_turn_residual_ = 0.0F;
        }
    }

    if (vehicle_mode && !ui_mode && delta_seconds > 0.0F &&
        std::abs(state.turn_y) > stick_threshold_) {
        const float normalized = std::copysign(
            (std::abs(state.turn_y) - stick_threshold_) /
                (1.0F - stick_threshold_), state.turn_y);
        vehicle_pitch_residual_ -= normalized *
            vehicle_pitch_counts_per_second_ * delta_seconds;
        const LONG dy = static_cast<LONG>(std::lround(vehicle_pitch_residual_));
        vehicle_pitch_residual_ -= static_cast<float>(dy);
        if (dy != 0) {
            INPUT input{};
            input.type = INPUT_MOUSE;
            input.mi.dy = dy;
            input.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_MOVE_NOCOALESCE;
            (void)SendInput(1, &input, sizeof(input));
        }
    } else {
        vehicle_pitch_residual_ = 0.0F;
    }

    if (ui_mode && std::abs(state.turn_y) > 0.55F &&
        (last_ui_scroll_.time_since_epoch().count() == 0 ||
         now - last_ui_scroll_ >= std::chrono::milliseconds(120))) {
        scroll_mouse(state.turn_y > 0.0F ? WHEEL_DELTA : -WHEEL_DELTA);
        last_ui_scroll_ = now;
    }

    if (!proxy_weapon_actions_) {
        tap_on_rising_edge(state.reload, reload_previous_, 'R');
        tap_on_rising_edge(state.fire_mode, fire_mode_previous_, 'F');
    } else {
        reload_previous_ = state.reload;
        fire_mode_previous_ = state.fire_mode;
    }
    // Never synthesize Escape/Pause from a VR controller. Combat and movement
    // buttons remain dedicated even when a mod keeps a UI display alive.
    // Hold Arma's native default-action key for the real controller press
    // duration. A zero-duration tap was easy for Arma's input polling to miss,
    // especially on doors and vehicle interaction points.
    set_key(VK_SPACE, state.interact && !ui_mode, interact_);
    // Combat bindings must not disappear because a mod left an invisible
    // helper display alive. They remain authoritative in every context.
    tap_on_rising_edge(state.vault, vault_previous_, 'V');
    tap_on_rising_edge(state.grenade, grenade_previous_, 'G');

    if (ui_mode) {
        const bool ui_accept = state.fire_mode;
        tap_on_rising_edge(ui_accept, ui_accept_previous_, VK_RETURN);
        // No UI-back binding here: Escape opens Arma's pause menu when a
        // third-party display closes between frames.
        ui_back_previous_ = state.swap_weapon;
        const bool ui_middle = state.sprint_click;
        if (ui_middle && !ui_middle_previous_) {
            bool held{};
            set_mouse_button(MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP, true, held);
            set_mouse_button(MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP, false, held);
        }
        ui_middle_previous_ = ui_middle;
    } else {
        ui_accept_previous_ = ui_back_previous_ = ui_middle_previous_ = false;
    }

    // Left grip remains reserved in this alpha. Never synthesize
    // grave/backspace here: keyboard layouts and conflicting Arma binds made
    // that open the native command menu instead.
    // Do not latch a native "radial" context here. Third-party menus own their
    // lifetime and may close without notifying the runtime. The old latch was
    // able to disable every stick/motion binding until the process restarted.
    radial_context_active_ = false;
    set_game_context_flag(3, false);
    radial_previous_ = state.radial_menu;
    // Weapon switching and three-state posture are handled by the addon from
    // the same controller telemetry. That is independent of keyboard profile
    // bindings and works for arbitrary primary/handgun classes.
    swap_previous_ = state.swap_weapon;
}

} // namespace a3vr
