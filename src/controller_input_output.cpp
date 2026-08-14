#include "controller_input_output.hpp"

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

bool game_cursor_is_visible() noexcept {
    CURSORINFO info{sizeof(info)};
    return GetCursorInfo(&info) != FALSE && (info.flags & CURSOR_SHOWING) != 0;
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
    smooth_turn_residual_ = 0.0F;
    last_update_ = {};
}

void ControllerInputOutput::update(
    const ControllerInputState& state, const std::uint32_t game_pid) noexcept {
    if (!enabled_ || !game_is_foreground(game_pid)) {
        release_all();
        reload_previous_ = state.reload;
        fire_mode_previous_ = state.fire_mode;
        swap_previous_ = state.swap_weapon;
        interact_previous_ = state.interact;
        vault_previous_ = state.vault;
        stand_previous_ = state.turn_y > stick_threshold_;
        crouch_previous_ = state.turn_y < -stick_threshold_;
        return;
    }

    const auto now = std::chrono::steady_clock::now();
    float delta_seconds{};
    if (last_update_.time_since_epoch().count() != 0) {
        delta_seconds = std::clamp(
            std::chrono::duration<float>(now - last_update_).count(), 0.0F, 0.05F);
    }
    last_update_ = now;

    const bool ui_mode = game_cursor_is_visible();
    const MovementKeys movement = ui_mode ? MovementKeys{} : movement_keys_from_stick(
        state.move_x, state.move_y, stick_threshold_);
    set_key('W', movement.forward, forward_);
    set_key('S', movement.backward, backward_);
    set_key('A', movement.left, left_);
    set_key('D', movement.right, right_);
    set_key(VK_LSHIFT, state.sprint && (movement.forward || movement.backward ||
                                       movement.left || movement.right), sprint_);
    // Keep native fire available for the magnified-optic fallback, where the
    // script camera is temporarily released. In proxy view SQF handles the
    // same trigger because Arma ignores this mouse event there.
    set_mouse_button(MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, state.fire, fire_);
    set_mouse_button(MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP, state.aim, aim_);

    if (smooth_turn_enabled_ && !ui_mode && delta_seconds > 0.0F) {
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

    if (!proxy_weapon_actions_) {
        tap_on_rising_edge(state.reload, reload_previous_, 'R');
        tap_on_rising_edge(state.fire_mode, fire_mode_previous_, 'F');
    } else {
        reload_previous_ = state.reload;
        fire_mode_previous_ = state.fire_mode;
    }
    tap_on_rising_edge(state.interact, interact_previous_, VK_SPACE);
    // Oculus Touch right B: throw the currently selected Arma grenade.
    tap_on_rising_edge(state.vault, vault_previous_, 'G');
    const bool stand = state.turn_y > stick_threshold_;
    const bool crouch = state.turn_y < -stick_threshold_;
    tap_on_rising_edge(stand, stand_previous_, 'C');
    tap_on_rising_edge(crouch, crouch_previous_, 'X');
    if (!proxy_weapon_actions_ && state.swap_weapon && !swap_previous_) {
        sidearm_selected_ = !sidearm_selected_;
        tap_key(sidearm_selected_ ? '2' : '1');
    }
    swap_previous_ = state.swap_weapon;
}

} // namespace a3vr
