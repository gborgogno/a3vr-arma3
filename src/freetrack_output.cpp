#include "freetrack_output.hpp"
#include "game_context.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <cstdlib>
#include <iterator>

namespace a3vr {
namespace {

constexpr float kTranslationGain = 0.25F;
constexpr float kMaximumYaw = 1.22173048F;   // 70 degrees
constexpr float kMaximumPitch = 0.87266463F; // 50 degrees
constexpr float kMaximumTranslationMm = 100.0F;
constexpr float kMaximumRecessedTranslationMm = 450.0F;

struct FreeTrackData {
    std::uint32_t data_id;
    std::int32_t camera_width;
    std::int32_t camera_height;
    float yaw;
    float pitch;
    float roll;
    float x;
    float y;
    float z;
    float raw_yaw;
    float raw_pitch;
    float raw_roll;
    float raw_x;
    float raw_y;
    float raw_z;
    float point_coordinates[8];
};

float dot(const Vec3 a, const Vec3 b) noexcept {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

Vec3 normalized(const Vec3 value) noexcept {
    const float length = std::sqrt(dot(value, value));
    if (length < 0.00001F) return {};
    return {value.x / length, value.y / length, value.z / length};
}

Quat conjugate(const Quat value) noexcept {
    return {-value.x, -value.y, -value.z, value.w};
}

Quat multiply(const Quat a, const Quat b) noexcept {
    return {
        a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
    };
}

Quat normalized_quaternion(const Quat value) noexcept {
    const float length = std::sqrt(
        value.x * value.x + value.y * value.y + value.z * value.z +
        value.w * value.w);
    if (!std::isfinite(length) || length < 0.00001F) return {};
    return {value.x / length, value.y / length, value.z / length,
            value.w / length};
}

TrackedPose relative_to(const TrackedPose& pose, const TrackedPose& origin) noexcept {
    const Quat inverse_origin = conjugate(origin.orientation);
    const Vec3 delta{pose.position.x - origin.position.x,
                     pose.position.y - origin.position.y,
                     pose.position.z - origin.position.z};
    return {pose.position_valid, pose.orientation_valid,
            rotate(inverse_origin, delta),
            multiply(inverse_origin, pose.orientation)};
}

} // namespace

struct FreeTrackOutput::SharedMemory {
    FreeTrackData data;
    std::int32_t game_id;
    unsigned char table[8];
    std::int32_t game_id_2;
};

static_assert(sizeof(FreeTrackData) == 92);

FreeTrackPose to_freetrack_pose(
    const TrackedPose& pose, const float rotation_gain) noexcept {
    const Vec3 forward = normalized(rotate(pose.orientation, {0.0F, 0.0F, -1.0F}));
    // Extract yaw from the quaternion's world-up twist instead of from the
    // projected forward vector. Looking past straight up otherwise makes the
    // forward vector cross the pole and injects an instantaneous 180-degree
    // yaw flip. Pitch uses a bounded elevation, so the camera cannot invert.
    const float canonical_sign = pose.orientation.w < 0.0F ? -1.0F : 1.0F;
    const float twist_w = pose.orientation.w * canonical_sign;
    const float twist_y = pose.orientation.y * canonical_sign;
    const float twist_length = std::hypot(twist_w, twist_y);
    const float yaw = twist_length > 0.00001F
        ? 2.0F * std::atan2(twist_y / twist_length, twist_w / twist_length)
        : 0.0F;
    const float pitch = std::atan2(
        forward.y, std::hypot(forward.x, forward.z));

    // Arma's FreeTrack camera consumes lateral translation with the opposite
    // sign to OpenXR: moving the headset right must move the in-game viewpoint
    // right, not mirror it to the left.
    return {
        std::clamp(yaw * rotation_gain, -kMaximumYaw, kMaximumYaw),
        std::clamp(pitch * rotation_gain, -kMaximumPitch, kMaximumPitch),
        0.0F, // Arma's FreeTrack path is unstable with roll near pitch limits.
        std::clamp(-pose.position.x * 1000.0F * kTranslationGain,
                   -kMaximumTranslationMm, kMaximumTranslationMm),
        std::clamp(pose.position.y * 1000.0F * kTranslationGain,
                   -kMaximumTranslationMm, kMaximumTranslationMm),
        std::clamp(-pose.position.z * 1000.0F * kTranslationGain,
                   -kMaximumTranslationMm, kMaximumTranslationMm),
    };
}

FreeTrackPose apply_body_recess(FreeTrackPose pose, const float forward_mm) noexcept {
    pose.z = std::clamp(
        pose.z + std::clamp(forward_mm, 0.0F, 400.0F),
        -kMaximumRecessedTranslationMm, kMaximumRecessedTranslationMm);
    return pose;
}

float head_roll_radians(const Quat& orientation) noexcept {
    const Vec3 forward = normalized(rotate(
        normalized_quaternion(orientation), {0.0F, 0.0F, -1.0F}));
    const Vec3 physical_right = normalized(rotate(
        normalized_quaternion(orientation), {1.0F, 0.0F, 0.0F}));
    // Build a gravity-level basis around the current forward ray. This keeps
    // yaw and pitch out of the roll measurement instead of relying on an Euler
    // decomposition whose result changes with rotation order.
    Vec3 level_right = normalized({-forward.z, 0.0F, forward.x});
    if (dot(level_right, level_right) < 0.5F) return 0.0F;
    const Vec3 level_up = normalized({
        level_right.y * forward.z - level_right.z * forward.y,
        level_right.z * forward.x - level_right.x * forward.z,
        level_right.x * forward.y - level_right.y * forward.x,
    });
    return std::atan2(dot(physical_right, level_up),
                      dot(physical_right, level_right));
}

TrackedPose compensate_view_space_roll(
    const TrackedPose& eye_pose, const float head_roll) noexcept {
    if (!std::isfinite(head_roll)) return eye_pose;
    const float half = -0.5F * head_roll;
    const Quat inverse_roll{0.0F, 0.0F, std::sin(half), std::cos(half)};
    TrackedPose corrected = eye_pose;
    corrected.position = rotate(inverse_roll, eye_pose.position);
    corrected.orientation = normalized_quaternion(
        multiply(inverse_roll, eye_pose.orientation));
    return corrected;
}

TrackedPose captured_projection_eye_pose(
    const Vec3 current_head_position, const Quat captured_orientation,
    const TrackedPose& eye_in_view_space) noexcept {
    const Quat orientation = normalized_quaternion(captured_orientation);
    const Vec3 eye_offset = rotate(orientation, eye_in_view_space.position);
    TrackedPose corrected = eye_in_view_space;
    corrected.position = {
        current_head_position.x + eye_offset.x,
        current_head_position.y + eye_offset.y,
        current_head_position.z + eye_offset.z};
    corrected.orientation = normalized_quaternion(
        multiply(orientation, eye_in_view_space.orientation));
    return corrected;
}

FreeTrackOutput::FreeTrackOutput() {
    char value[32]{};
    const DWORD size = GetEnvironmentVariableA(
        "A3VR_HEAD_ROTATION_GAIN", value,
        static_cast<DWORD>(std::size(value)));
    if (size > 0 && size < std::size(value)) {
        const float parsed = std::strtof(value, nullptr);
        if (parsed >= 0.10F && parsed <= 1.50F) rotation_gain_ = parsed;
    }

    char recess_value[32]{};
    const DWORD recess_size = GetEnvironmentVariableA(
        "A3VR_BODY_RECESS_MM", recess_value,
        static_cast<DWORD>(std::size(recess_value)));
    if (recess_size > 0 && recess_size < std::size(recess_value)) {
        const float parsed = std::strtof(recess_value, nullptr);
        if (parsed >= 0.0F && parsed <= 400.0F) body_recess_mm_ = parsed;
    }
}

FreeTrackOutput::~FreeTrackOutput() { close(); }

bool FreeTrackOutput::open() {
    static_assert(sizeof(SharedMemory) == 108);
    if (data_ != nullptr) return true;
    mutex_ = CreateMutexA(nullptr, FALSE, "FT_Mutext");
    mapping_ = CreateFileMappingA(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE,
                                  0, sizeof(SharedMemory), "FT_SharedMem");
    if (mutex_ == nullptr || mapping_ == nullptr) {
        close();
        return false;
    }
    data_ = static_cast<SharedMemory*>(MapViewOfFile(
        mapping_, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(SharedMemory)));
    if (data_ == nullptr) {
        close();
        return false;
    }
    return true;
}

void FreeTrackOutput::close() {
    if (data_ != nullptr) UnmapViewOfFile(data_);
    if (mapping_ != nullptr) CloseHandle(mapping_);
    if (mutex_ != nullptr) CloseHandle(mutex_);
    data_ = nullptr;
    mapping_ = nullptr;
    mutex_ = nullptr;
    origin_valid_ = false;
    origin_ = {};
    presentation_roll_ = 0.0F;
    presentation_orientation_ = {};
    presentation_orientation_valid_ = false;
}

void FreeTrackOutput::recenter() noexcept {
    origin_valid_ = false;
    origin_ = {};
    presentation_roll_ = 0.0F;
    presentation_orientation_ = {};
    presentation_orientation_valid_ = false;
}

void FreeTrackOutput::transfer_body_yaw(
    const float arma_yaw_radians) noexcept {
    if (!origin_valid_ || !std::isfinite(arma_yaw_radians)) return;
    // Arma headings increase clockwise, while OpenXR positive yaw is
    // counter-clockwise. FreeTrack rotation is gain-scaled, so transfer the
    // inverse, unscaled amount into the origin to keep the world view stable
    // while the native body turns underneath it.
    const float openxr_yaw = -arma_yaw_radians /
        (std::max)(rotation_gain_, 0.01F);
    const float half = openxr_yaw * 0.5F;
    const Quat yaw_rotation{0.0F, std::sin(half), 0.0F, std::cos(half)};
    origin_.orientation = normalized_quaternion(
        multiply(origin_.orientation, yaw_rotation));
}

void FreeTrackOutput::publish(const TrackedPose& pose) {
    if (data_ == nullptr || !pose.position_valid || !pose.orientation_valid) return;
    if (WaitForSingleObject(mutex_, 2) != WAIT_OBJECT_0) return;

    if (!origin_valid_) {
        origin_ = pose;
        origin_valid_ = true;
    }
    const TrackedPose relative_pose = relative_to(pose, origin_);
    presentation_roll_ = head_roll_radians(relative_pose.orientation);
    const bool in_vehicle = (game_context() & game_context_vehicle) != 0U;
    const FreeTrackPose rotation = to_freetrack_pose(
        relative_pose, rotation_gain_);
    const float half_yaw = rotation.yaw * 0.5F;
    const float half_pitch = rotation.pitch * 0.5F;
    const Quat yaw_orientation{
        0.0F, std::sin(half_yaw), 0.0F, std::cos(half_yaw)};
    const Quat pitch_orientation{
        std::sin(half_pitch), 0.0F, 0.0F, std::cos(half_pitch)};
    presentation_orientation_ = normalized_quaternion(multiply(
        origin_.orientation, multiply(yaw_orientation, pitch_orientation)));
    presentation_orientation_valid_ = true;
    const FreeTrackPose converted = apply_body_recess(
        rotation,
        in_vehicle ? 0.0F : body_recess_mm_);
    auto& output = data_->data;
    output.yaw = output.raw_yaw = converted.yaw;
    output.pitch = output.raw_pitch = converted.pitch;
    output.roll = output.raw_roll = converted.roll;
    output.x = output.raw_x = converted.x;
    output.y = output.raw_y = converted.y;
    output.z = output.raw_z = converted.z;
    ++output.data_id;

    ReleaseMutex(mutex_);
}

} // namespace a3vr
