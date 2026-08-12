#include "shared_state.hpp"

#include <algorithm>
#include <cstring>

namespace a3vr {
namespace {
constexpr char mapping_name[] = "Local\\A3VR_Tracking_v30";
constexpr char mutex_name[] = "Local\\A3VR_Tracking_Mutex_v30";
constexpr std::uint32_t magic = 0x52563341; // A3VR
}

struct SharedState::Block {
    std::uint32_t magic_value{};
    std::uint32_t version{};
    std::uint32_t server_pid{};
    std::uint32_t reserved{};
    TrackingSnapshot snapshot{};
    SharedRenderFrame render{};
    char status[256]{};
};

SharedState::~SharedState() { close(); }

bool SharedState::map(HANDLE mapping) {
    mapping_ = mapping;
    mutex_ = CreateMutexA(nullptr, FALSE, mutex_name);
    block_ = static_cast<Block*>(MapViewOfFile(mapping_, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(Block)));
    if (mutex_ == nullptr || block_ == nullptr) {
        close();
        return false;
    }
    return true;
}

bool SharedState::create() {
    close();
    HANDLE mapping = CreateFileMappingA(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE,
                                        0, sizeof(Block), mapping_name);
    if (mapping == nullptr || !map(mapping)) return false;
    std::memset(block_, 0, sizeof(Block));
    block_->magic_value = magic;
    block_->version = 10;
    block_->server_pid = GetCurrentProcessId();
    strcpy_s(block_->status, "starting");
    return true;
}

bool SharedState::connect() {
    if (block_ != nullptr) return true;
    HANDLE mapping = OpenFileMappingA(FILE_MAP_ALL_ACCESS, FALSE, mapping_name);
    if (mapping == nullptr || !map(mapping)) return false;
    if (block_->magic_value != magic || block_->version != 10) {
        close();
        return false;
    }
    return true;
}

void SharedState::close() {
    if (block_ != nullptr) UnmapViewOfFile(block_);
    if (mapping_ != nullptr) CloseHandle(mapping_);
    if (mutex_ != nullptr) CloseHandle(mutex_);
    block_ = nullptr;
    mapping_ = nullptr;
    mutex_ = nullptr;
}

void SharedState::publish(const TrackingSnapshot& snapshot, const std::string& status) {
    if (block_ == nullptr || WaitForSingleObject(mutex_, 5) != WAIT_OBJECT_0) return;
    block_->snapshot = snapshot;
    const auto count = std::min<std::size_t>(status.size(), sizeof(block_->status) - 1);
    std::memcpy(block_->status, status.data(), count);
    block_->status[count] = '\0';
    ReleaseMutex(mutex_);
}

bool SharedState::read(TrackingSnapshot& snapshot, std::string& status) {
    if (!connect() || WaitForSingleObject(mutex_, 5) != WAIT_OBJECT_0) return false;
    snapshot = block_->snapshot;
    status = block_->status;
    ReleaseMutex(mutex_);
    return true;
}

bool SharedState::publish_render(const SharedRenderFrame& frame) {
    if (!connect() || WaitForSingleObject(mutex_, 0) != WAIT_OBJECT_0) return false;
    block_->render = frame;
    ReleaseMutex(mutex_);
    return true;
}

bool SharedState::read_render(SharedRenderFrame& frame) {
    if (!connect() || WaitForSingleObject(mutex_, 0) != WAIT_OBJECT_0) return false;
    frame = block_->render;
    ReleaseMutex(mutex_);
    return true;
}

} // namespace a3vr
