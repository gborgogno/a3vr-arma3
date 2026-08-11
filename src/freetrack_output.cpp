#include "freetrack_output.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace a3vr {
namespace {

constexpr float kRotationGain = 0.25F;
constexpr float kTranslationGain = 0.25F;
constexpr float kMaximumYaw = 1.74532925F;   // 100 degrees
constexpr float kMaximumPitch = 1.39626340F; // 80 degrees
constexpr float kMaximumTranslationMm = 100.0F;

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

FreeTrackPose to_freetrack_pose(const TrackedPose& pose) noexcept {
    const Vec3 forward = normalized(rotate(pose.orientation, {0.0F, 0.0F, -1.0F}));
    const float pitch = std::asin(std::clamp(forward.y, -1.0F, 1.0F));
    const float yaw = std::atan2(-forward.x, -forward.z);

    // Arma's FreeTrack camera consumes lateral translation with the opposite
    // sign to OpenXR: moving the headset right must move the in-game viewpoint
    // right, not mirror it to the left.
    return {
        std::clamp(yaw * kRotationGain, -kMaximumYaw, kMaximumYaw),
        std::clamp(pitch * kRotationGain, -kMaximumPitch, kMaximumPitch),
        0.0F, // Arma's FreeTrack path is unstable with roll near pitch limits.
        std::clamp(-pose.position.x * 1000.0F * kTranslationGain,
                   -kMaximumTranslationMm, kMaximumTranslationMm),
        std::clamp(pose.position.y * 1000.0F * kTranslationGain,
                   -kMaximumTranslationMm, kMaximumTranslationMm),
        std::clamp(-pose.position.z * 1000.0F * kTranslationGain,
                   -kMaximumTranslationMm, kMaximumTranslationMm),
    };
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
    const FreeTrackPose converted = to_freetrack_pose(relative_to(pose, origin_));
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
