#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <windows.h>

namespace a3vr {

enum GameContextFlag : std::uint32_t {
    game_context_ui = 1U,
    game_context_zeus = 2U,
    game_context_vehicle = 4U,
    game_context_radial = 8U,
    game_option_aim_left = 16U,
    game_option_pointer_head = 32U,
    game_option_turn_fast = 64U,
    game_option_turn_slow = 128U,
    game_option_ui_large = 256U,
    game_option_movement_head = 512U,
    game_context_gameplay = 1024U,
    game_option_proxy_active = 2048U,
    game_option_native_ads = 4096U,
    game_option_motion_aim = 8192U,
    game_context_mouse_ui = 16384U,
};

inline HANDLE game_context_event(const std::size_t index) noexcept {
    static const std::array<const wchar_t*, 15> names{
        L"Local\\A3VR_UI_Mode_v31",
        L"Local\\A3VR_Zeus_Mode_v31",
        L"Local\\A3VR_Vehicle_Mode_v31",
        L"Local\\A3VR_Radial_Mode_v31",
        L"Local\\A3VR_Aim_Left_v31",
        L"Local\\A3VR_Pointer_Head_v31",
        L"Local\\A3VR_Turn_Fast_v31",
        L"Local\\A3VR_Turn_Slow_v31",
        L"Local\\A3VR_UI_Large_v31",
        L"Local\\A3VR_Movement_Head_v31",
        L"Local\\A3VR_Gameplay_Mode_v31",
        L"Local\\A3VR_Proxy_Mode_v31",
        L"Local\\A3VR_Native_ADS_v31",
        L"Local\\A3VR_Motion_Aim_v31",
        L"Local\\A3VR_Mouse_UI_v31",
    };
    static std::array<HANDLE, 15> handles{};
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
    // SQF owns only these four detected game states. The radial flag is
    // toggled independently by the controller runtime and must be preserved.
    struct OwnedContextFlag {
        std::size_t event_index;
        std::uint32_t mask;
    };
    constexpr std::array<OwnedContextFlag, 5> owned_flags{{
        {0, game_context_ui},
        {1, game_context_zeus},
        {2, game_context_vehicle},
        {10, game_context_gameplay},
        {14, game_context_mouse_ui},
    }};
    for (const OwnedContextFlag owned : owned_flags) {
        if (HANDLE event = game_context_event(owned.event_index)) {
            if ((flags & owned.mask) != 0U) SetEvent(event);
            else ResetEvent(event);
        }
    }
}

inline std::uint32_t game_context() noexcept {
    constexpr std::array<std::uint32_t, 15> masks{
        game_context_ui, game_context_zeus, game_context_vehicle,
        game_context_radial, game_option_aim_left,
        game_option_pointer_head, game_option_turn_fast,
        game_option_turn_slow, game_option_ui_large,
        game_option_movement_head, game_context_gameplay,
        game_option_proxy_active, game_option_native_ads,
        game_option_motion_aim, game_context_mouse_ui};
    std::uint32_t flags{};
    for (std::size_t index = 0; index < masks.size(); ++index) {
        if (HANDLE event = game_context_event(index);
            event != nullptr && WaitForSingleObject(event, 0) == WAIT_OBJECT_0) {
            flags |= masks[index];
        }
    }
    return flags;
}

inline HANDLE recenter_request_event() noexcept {
    static HANDLE event = CreateEventW(
        nullptr, FALSE, FALSE, L"Local\\A3VR_Recenter_Request_v31");
    return event;
}

inline void request_recenter() noexcept {
    if (HANDLE event = recenter_request_event()) SetEvent(event);
}

inline bool consume_recenter_request() noexcept {
    if (HANDLE event = recenter_request_event()) {
        return WaitForSingleObject(event, 0) == WAIT_OBJECT_0;
    }
    return false;
}

inline volatile LONG* body_yaw_transfer_accumulator() noexcept {
    static HANDLE mapping = CreateFileMappingW(
        INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE, 0, sizeof(LONG),
        L"Local\\A3VR_Body_Yaw_Transfer_v31");
    static volatile LONG* value = mapping != nullptr
        ? static_cast<volatile LONG*>(MapViewOfFile(
            mapping, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(LONG)))
        : nullptr;
    return value;
}

inline void request_body_yaw_transfer(const float degrees) noexcept {
    if (!std::isfinite(degrees)) return;
    if (volatile LONG* value = body_yaw_transfer_accumulator()) {
        constexpr float units_per_degree = 10000.0F;
        const LONG units = static_cast<LONG>(std::lround(
            std::clamp(degrees, -20.0F, 20.0F) * units_per_degree));
        InterlockedExchangeAdd(value, units);
    }
}

inline float consume_body_yaw_transfer() noexcept {
    if (volatile LONG* value = body_yaw_transfer_accumulator()) {
        constexpr float units_per_degree = 10000.0F;
        return static_cast<float>(InterlockedExchange(value, 0)) /
            units_per_degree;
    }
    return 0.0F;
}

} // namespace a3vr
