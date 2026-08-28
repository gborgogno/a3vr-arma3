#pragma once

#include <array>
#include <cmath>
#include <cstdint>

namespace a3vr {

struct Vec3 {
    float x{};
    float y{};
    float z{};
};

struct Quat {
    float x{};
    float y{};
    float z{};
    float w{1.0F};
};

struct TrackedPose {
    bool position_valid{};
    bool orientation_valid{};
    Vec3 position{};
    Quat orientation{};
};

enum class MotionAimMode : std::uint32_t {
    legacy_relative = 0,
    absolute_weapon = 1,
};

struct WeaponPoseTarget {
    bool valid{};
    TrackedPose room_pose{};
    TrackedPose player_pose{};
    Vec3 muzzle_origin{};
    Vec3 muzzle_direction{};
};

// Feedback produced by the Arma-side addon for the weapon that actually owns
// the muzzle, particles, ammunition and reload animation.  The OpenXR runtime
// uses it to close the controller-aim loop instead of blindly accumulating
// controller deltas.
struct AimFeedback {
    std::uint64_t sequence{};
    bool valid{};
    Vec3 weapon_direction{};
};

struct HapticRequest {
    std::uint64_t sequence{};
    float amplitude{};
    float frequency{};
    std::uint32_t duration_ms{};
    std::uint32_t hand_mask{}; // bit 0 left, bit 1 right
};

struct EyeView {
    TrackedPose pose{};
    std::array<float, 4> fov{}; // left, right, up, down angles in radians
};

struct TrackingSnapshot {
    std::uint64_t sequence{};
    std::int64_t predicted_display_time{};
    std::int32_t session_state{};
    bool session_running{};
    TrackedPose head{};
    bool presentation_orientation_valid{};
    Quat presentation_orientation{};
    TrackedPose left_hand{};
    TrackedPose right_hand{};
    std::array<EyeView, 2> eyes{};
    std::array<float, 5> left_finger_curls{};
    float controller_move_x{};
    float controller_move_y{};
    float controller_turn_x{};
    float controller_turn_y{};
    std::uint32_t controller_buttons{};
    MotionAimMode motion_aim_mode{MotionAimMode::legacy_relative};
    WeaponPoseTarget weapon_target{};
};

// OpenXR: +X right, +Y up, -Z forward.
// Arma world/model vectors: +X right, +Y forward, +Z up.
constexpr Vec3 xr_to_arma_position(const Vec3 value) noexcept {
    return {value.x, -value.z, value.y};
}

inline Vec3 rotate(const Quat q, const Vec3 v) noexcept {
    const Vec3 qv{q.x, q.y, q.z};
    const Vec3 t{
        2.0F * (qv.y * v.z - qv.z * v.y),
        2.0F * (qv.z * v.x - qv.x * v.z),
        2.0F * (qv.x * v.y - qv.y * v.x),
    };
    return {
        v.x + q.w * t.x + (qv.y * t.z - qv.z * t.y),
        v.y + q.w * t.y + (qv.z * t.x - qv.x * t.z),
        v.z + q.w * t.z + (qv.x * t.y - qv.y * t.x),
    };
}

inline Vec3 arma_direction(const Quat q) noexcept {
    return xr_to_arma_position(rotate(q, {0.0F, 0.0F, -1.0F}));
}

inline Vec3 arma_up(const Quat q) noexcept {
    return xr_to_arma_position(rotate(q, {0.0F, 1.0F, 0.0F}));
}

} // namespace a3vr
