#pragma once

#include "pose.hpp"

#include <cstdint>
#include <windows.h>

namespace a3vr {

struct FreeTrackPose {
    float yaw{};
    float pitch{};
    float roll{};
    float x{};
    float y{};
    float z{};
};

FreeTrackPose to_freetrack_pose(
    const TrackedPose& pose, float rotation_gain = 0.42F) noexcept;
FreeTrackPose apply_body_recess(FreeTrackPose pose, float forward_mm) noexcept;
float head_roll_radians(const Quat& orientation) noexcept;
TrackedPose compensate_view_space_roll(
    const TrackedPose& eye_pose, float head_roll) noexcept;
TrackedPose captured_projection_eye_pose(
    Vec3 current_head_position, Quat captured_orientation,
    const TrackedPose& eye_in_view_space) noexcept;

class FreeTrackOutput final {
public:
    FreeTrackOutput();
    ~FreeTrackOutput();
    FreeTrackOutput(const FreeTrackOutput&) = delete;
    FreeTrackOutput& operator=(const FreeTrackOutput&) = delete;

    bool open();
    void close();
    void recenter() noexcept;
    void transfer_body_yaw(float arma_yaw_radians) noexcept;
    void publish(const TrackedPose& pose);
    [[nodiscard]] bool active() const noexcept { return data_ != nullptr; }
    [[nodiscard]] float presentation_roll() const noexcept {
        return presentation_roll_;
    }
    [[nodiscard]] Quat presentation_orientation() const noexcept {
        return presentation_orientation_;
    }
    [[nodiscard]] bool presentation_orientation_valid() const noexcept {
        return presentation_orientation_valid_;
    }

private:
    struct SharedMemory;
    HANDLE mapping_{};
    HANDLE mutex_{};
    SharedMemory* data_{};
    bool origin_valid_{};
    TrackedPose origin_{};
    float rotation_gain_{0.42F};
    float body_recess_mm_{140.0F};
    float presentation_roll_{};
    Quat presentation_orientation_{};
    bool presentation_orientation_valid_{};
};

} // namespace a3vr
