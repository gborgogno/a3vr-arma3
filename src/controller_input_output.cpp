#include "controller_input_output.hpp"

#include <algorithm>
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
    enabled_ = enabled_size > 0 && std::string_view(enabled_value) == "1";

    char threshold_value[32]{};
    const DWORD threshold_size = GetEnvironmentVariableA(
        "A3VR_CONTROLLER_STICK_THRESHOLD", threshold_value,
        static_cast<DWORD>(std::size(threshold_value)));
    if (threshold_size > 0 && threshold_size < std::size(threshold_value)) {
        const float parsed = std::strtof(threshold_value, nullptr);
        if (parsed >= 0.1F && parsed <= 0.9F) stick_threshold_ = parsed;
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
}

void ControllerInputOutput::update(
    const ControllerInputState& state, const std::uint32_t game_pid) noexcept {
    if (!enabled_ || !game_is_foreground(game_pid)) {
        release_all();
        reload_previous_ = state.reload;
        fire_mode_previous_ = state.fire_mode;
        swap_previous_ = state.swap_weapon;
        interact_previous_ = state.interact;
        return;
    }

    const MovementKeys movement = movement_keys_from_stick(
        state.move_x, state.move_y, stick_threshold_);
    set_key('W', movement.forward, forward_);
    set_key('S', movement.backward, backward_);
    set_key('A', movement.left, left_);
    set_key('D', movement.right, right_);
    set_key(VK_LSHIFT, state.sprint && (movement.forward || movement.backward ||
                                       movement.left || movement.right), sprint_);
    set_mouse_button(MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, state.fire, fire_);
    set_mouse_button(MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP, state.aim, aim_);

    tap_on_rising_edge(state.reload, reload_previous_, 'R');
    tap_on_rising_edge(state.fire_mode, fire_mode_previous_, 'F');
    tap_on_rising_edge(state.interact, interact_previous_, VK_SPACE);
    if (state.swap_weapon && !swap_previous_) {
        sidearm_selected_ = !sidearm_selected_;
        tap_key(sidearm_selected_ ? '2' : '1');
    }
    swap_previous_ = state.swap_weapon;
}

} // namespace a3vr
