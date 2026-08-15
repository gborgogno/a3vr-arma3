#pragma once

#include <array>
#include <cstdint>
#include <windows.h>

namespace a3vr {

enum GameContextFlag : std::uint32_t {
    game_context_ui = 1U,
    game_context_zeus = 2U,
    game_context_vehicle = 4U,
    game_context_radial = 8U,
};

inline HANDLE game_context_event(const std::size_t index) noexcept {
    static const std::array<const wchar_t*, 4> names{
        L"Local\\A3VR_UI_Mode_v30",
        L"Local\\A3VR_Zeus_Mode_v30",
        L"Local\\A3VR_Vehicle_Mode_v30",
        L"Local\\A3VR_Radial_Mode_v30",
    };
    static std::array<HANDLE, 4> handles{};
    if (index >= handles.size()) return nullptr;
    if (handles[index] == nullptr) {
        handles[index] = CreateEventW(nullptr, TRUE, FALSE, names[index]);
    }
    return handles[index];
}

inline void set_game_context_flag(const std::size_t index,
                                  const bool enabled) noexcept {
    if (HANDLE event = game_context_event(index)) {
        if (enabled) SetEvent(event);
        else ResetEvent(event);
    }
}

inline void set_game_context(const std::uint32_t flags) noexcept {
    // SQF owns only these three detected game states. The radial flag is
    // toggled independently by the controller runtime and must be preserved.
    constexpr std::array<std::uint32_t, 3> masks{
        game_context_ui, game_context_zeus, game_context_vehicle};
    for (std::size_t index = 0; index < masks.size(); ++index) {
        if (HANDLE event = game_context_event(index)) {
            if ((flags & masks[index]) != 0U) SetEvent(event);
            else ResetEvent(event);
        }
    }
}

inline std::uint32_t game_context() noexcept {
    constexpr std::array<std::uint32_t, 4> masks{
        game_context_ui, game_context_zeus, game_context_vehicle,
        game_context_radial};
    std::uint32_t flags{};
    for (std::size_t index = 0; index < masks.size(); ++index) {
        if (HANDLE event = game_context_event(index);
            event != nullptr && WaitForSingleObject(event, 0) == WAIT_OBJECT_0) {
            flags |= masks[index];
        }
    }
    return flags;
}

} // namespace a3vr
