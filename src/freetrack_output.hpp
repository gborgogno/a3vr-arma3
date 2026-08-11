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

FreeTrackPose to_freetrack_pose(const TrackedPose& pose) noexcept;

class FreeTrackOutput final {
public:
    FreeTrackOutput() = default;
    ~FreeTrackOutput();
    FreeTrackOutput(const FreeTrackOutput&) = delete;
    FreeTrackOutput& operator=(const FreeTrackOutput&) = delete;

    bool open();
    void close();
    void recenter() noexcept;
    void publish(const TrackedPose& pose);
    [[nodiscard]] bool active() const noexcept { return data_ != nullptr; }

private:
    struct SharedMemory;
    HANDLE mapping_{};
    HANDLE mutex_{};
    SharedMemory* data_{};
    bool origin_valid_{};
    TrackedPose origin_{};
};

} // namespace a3vr
