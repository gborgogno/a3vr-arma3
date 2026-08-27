#pragma once

#include "pose.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace a3vr {

struct RigidTransform {
    Vec3 position{};
    Quat orientation{};
};

struct WeaponGripCalibration {
    Vec3 position_offset{};
    Quat rotation_offset{};
};

inline Vec3 add(const Vec3 a, const Vec3 b) noexcept {
    return {a.x + b.x, a.y + b.y, a.z + b.z};
}

inline Vec3 subtract(const Vec3 a, const Vec3 b) noexcept {
    return {a.x - b.x, a.y - b.y, a.z - b.z};
}

inline float length_squared(const Quat value) noexcept {
    return value.x * value.x + value.y * value.y +
           value.z * value.z + value.w * value.w;
}

inline Quat normalized(const Quat value) noexcept {
    const float magnitude_squared = length_squared(value);
    if (magnitude_squared <= 0.000001F) return {};
    const float reciprocal = 1.0F / std::sqrt(magnitude_squared);
    return {value.x * reciprocal, value.y * reciprocal,
            value.z * reciprocal, value.w * reciprocal};
}

inline Quat multiply(const Quat lhs, const Quat rhs) noexcept {
    return normalized({
        lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
        lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
        lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w,
        lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
    });
}

inline Quat inverse(const Quat value) noexcept {
    const Quat unit = normalized(value);
    return {-unit.x, -unit.y, -unit.z, unit.w};
}

inline RigidTransform compose(const RigidTransform parent,
                              const RigidTransform local) noexcept {
    return {
        add(parent.position, rotate(parent.orientation, local.position)),
        multiply(parent.orientation, local.orientation),
    };
}

inline RigidTransform inverse(const RigidTransform value) noexcept {
    const Quat rotation = inverse(value.orientation);
    return {rotate(rotation, {-value.position.x, -value.position.y,
                              -value.position.z}), rotation};
}

inline Quat quaternion_from_yaw_pitch_roll(const float yaw,
                                            const float pitch,
                                            const float roll) noexcept {
    const float half_yaw = yaw * 0.5F;
    const float half_pitch = pitch * 0.5F;
    const float half_roll = roll * 0.5F;
    const Quat yaw_rotation{0.0F, std::sin(half_yaw), 0.0F, std::cos(half_yaw)};
    const Quat pitch_rotation{std::sin(half_pitch), 0.0F, 0.0F,
                              std::cos(half_pitch)};
    const Quat roll_rotation{0.0F, 0.0F, std::sin(half_roll),
                             std::cos(half_roll)};
    return multiply(multiply(yaw_rotation, pitch_rotation), roll_rotation);
}

class AbsoluteWeaponPoseSolver final {
public:
    void set_calibration(const WeaponGripCalibration calibration) noexcept {
        calibration_ = calibration;
        calibration_.rotation_offset = normalized(calibration_.rotation_offset);
    }

    void set_muzzle_offset(const Vec3 offset) noexcept { muzzle_offset_ = offset; }

    void clear_player_origin() noexcept {
        player_origin_valid_ = false;
        room_from_player_ = {};
    }

    void establish_player_origin(const TrackedPose& head) noexcept {
        if (!head.position_valid) return;
        // The room origin is captured once and remains stable. Head motion on
        // later frames therefore cannot redefine the controller/weapon pose.
        room_from_player_.position = {head.position.x, 0.0F, head.position.z};
        room_from_player_.orientation = {};
        player_origin_valid_ = true;
    }

    [[nodiscard]] WeaponPoseTarget solve(const TrackedPose& controller,
                                         const TrackedPose& head) noexcept {
        WeaponPoseTarget result{};
        if (!controller.position_valid || !controller.orientation_valid) return result;
        if (!player_origin_valid_) establish_player_origin(head);

        // Explicit transform chain:
        // OpenXR room -> controller -> calibrated weapon grip -> weapon.
        const RigidTransform room_from_controller{
            controller.position, normalized(controller.orientation)};
        const RigidTransform controller_from_weapon{
            calibration_.position_offset, calibration_.rotation_offset};
        const RigidTransform room_from_weapon =
            compose(room_from_controller, controller_from_weapon);

        result.valid = true;
        result.room_pose = {true, true, room_from_weapon.position,
                            room_from_weapon.orientation};

        const RigidTransform player_from_room = inverse(room_from_player_);
        const RigidTransform player_from_weapon =
            compose(player_from_room, room_from_weapon);
        result.player_pose = {player_origin_valid_, true,
                              player_from_weapon.position,
                              player_from_weapon.orientation};

        result.muzzle_origin = add(
            room_from_weapon.position,
            rotate(room_from_weapon.orientation, muzzle_offset_));
        result.muzzle_direction = rotate(
            room_from_weapon.orientation, {0.0F, 0.0F, -1.0F});
        return result;
    }

private:
    WeaponGripCalibration calibration_{};
    Vec3 muzzle_offset_{0.0F, 0.0F, -0.55F};
    bool player_origin_valid_{};
    RigidTransform room_from_player_{};
};

} // namespace a3vr
