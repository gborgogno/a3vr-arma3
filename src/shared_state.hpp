#pragma once

#include "pose.hpp"

#include <cstdint>
#include <string>
#include <windows.h>

namespace a3vr {

struct SharedRenderFrame {
    std::uint64_t generation{};
    std::uint64_t frame_sequence{};
    std::uint64_t shared_handle{};
    std::uint32_t source_pid{};
    std::uint32_t width{};
    std::uint32_t height{};
    std::uint32_t dxgi_format{};
    std::uint32_t capture_state{}; // 1 hook, 2 texture error, 3 frames flowing
    std::int32_t last_hresult{};
};

class SharedState final {
public:
    SharedState() = default;
    ~SharedState();
    SharedState(const SharedState&) = delete;
    SharedState& operator=(const SharedState&) = delete;

    bool create();
    bool connect();
    void close();
    void publish(const TrackingSnapshot& snapshot, const std::string& status);
    bool read(TrackingSnapshot& snapshot, std::string& status);
    bool publish_render(const SharedRenderFrame& frame);
    bool read_render(SharedRenderFrame& frame);

private:
    struct Block;
    bool map(HANDLE mapping);
    HANDLE mapping_{};
    HANDLE mutex_{};
    Block* block_{};
};

} // namespace a3vr
