#include "freetrack_output.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <cstdlib>
#include <iterator>

namespace a3vr {
namespace {

constexpr float kTranslationGain = 0.25F;
constexpr float kMaximumYaw = 1.74532925F;   // 100 degrees
constexpr float kMaximumPitch = 1.39626340F; // 80 degrees
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
    const float pitch = std::asin(std::clamp(forward.y, -1.0F, 1.0F));
    const float yaw = std::atan2(-forward.x, -forward.z);

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
}

void FreeTrackOutput::recenter() noexcept {
    origin_valid_ = false;
    origin_ = {};
}

void FreeTrackOutput::publish(const TrackedPose& pose) {
    if (data_ == nullptr || !pose.position_valid || !pose.orientation_valid) return;
    if (WaitForSingleObject(mutex_, 2) != WAIT_OBJECT_0) return;

    if (!origin_valid_) {
        origin_ = pose;
        origin_valid_ = true;
    }
    const FreeTrackPose converted = apply_body_recess(
        to_freetrack_pose(relative_to(pose, origin_), rotation_gain_),
        body_recess_mm_);
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
