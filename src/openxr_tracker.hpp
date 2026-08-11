#pragma once

#include "pose.hpp"
#include "controller_aim_output.hpp"
#include "controller_input_output.hpp"
#include "freetrack_output.hpp"
#include "shared_state.hpp"

#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <d3d11_1.h>
#include <wrl/client.h>
#include <openxr/openxr.h>
#include <openxr/openxr_platform.h>

namespace a3vr {

class OpenXrTracker final {
public:
    static OpenXrTracker& instance();

    OpenXrTracker(const OpenXrTracker&) = delete;
    OpenXrTracker& operator=(const OpenXrTracker&) = delete;

    bool start();
    void stop();
    [[nodiscard]] TrackingSnapshot snapshot() const;
    [[nodiscard]] std::string status() const;
    [[nodiscard]] bool running() const noexcept { return worker_running_.load(); }

private:
    OpenXrTracker() = default;
    ~OpenXrTracker();

    void worker_main();
    bool initialize();
    void shutdown();
    bool create_d3d_device(const LUID& adapter_luid, D3D_FEATURE_LEVEL minimum_level);
    bool create_actions();
    bool update_shared_render_source();
    bool create_render_swapchains(const SharedRenderFrame& frame);
    void destroy_render_resources();
    void poll_events();
    void run_frame();
    void set_status(std::string message);
    void set_error(std::string message);

    std::atomic_bool stop_requested_{false};
    std::atomic_bool worker_running_{false};
    std::thread worker_{};

    mutable std::mutex data_mutex_{};
    TrackingSnapshot snapshot_{};
    std::string status_{"stopped"};

    XrInstance instance_{XR_NULL_HANDLE};
    XrSystemId system_id_{XR_NULL_SYSTEM_ID};
    XrSession session_{XR_NULL_HANDLE};
    std::atomic<XrSession> session_for_stop_{XR_NULL_HANDLE};
    XrSpace local_space_{XR_NULL_HANDLE};
    XrSpace view_space_{XR_NULL_HANDLE};
    XrSessionState session_state_{XR_SESSION_STATE_UNKNOWN};
    bool session_running_{false};
    bool sbs_mode_{false};
    bool mono_mode_{false};

    XrActionSet action_set_{XR_NULL_HANDLE};
    XrAction hand_pose_action_{XR_NULL_HANDLE};
    XrAction fire_action_{XR_NULL_HANDLE};
    XrAction aim_action_{XR_NULL_HANDLE};
    XrAction move_action_{XR_NULL_HANDLE};
    XrAction move_x_action_{XR_NULL_HANDLE};
    XrAction move_y_action_{XR_NULL_HANDLE};
    XrAction right_move_action_{XR_NULL_HANDLE};
    XrAction right_move_x_action_{XR_NULL_HANDLE};
    XrAction right_move_y_action_{XR_NULL_HANDLE};
    XrAction sprint_action_{XR_NULL_HANDLE};
    XrAction reload_action_{XR_NULL_HANDLE};
    XrAction fire_mode_action_{XR_NULL_HANDLE};
    XrAction swap_weapon_action_{XR_NULL_HANDLE};
    XrAction motion_toggle_action_{XR_NULL_HANDLE};
    XrAction interact_action_{XR_NULL_HANDLE};
    std::array<XrPath, 2> hand_paths_{};
    std::array<XrSpace, 2> hand_spaces_{XR_NULL_HANDLE, XR_NULL_HANDLE};

    Microsoft::WRL::ComPtr<ID3D11Device> d3d_device_{};
    Microsoft::WRL::ComPtr<ID3D11DeviceContext> d3d_context_{};
    struct EyeSwapchain {
        XrSwapchain handle{XR_NULL_HANDLE};
        std::vector<XrSwapchainImageD3D11KHR> images{};
    };
    std::array<EyeSwapchain, 2> eye_swapchains_{};
    Microsoft::WRL::ComPtr<ID3D11Texture2D> game_texture_{};
    Microsoft::WRL::ComPtr<IDXGIKeyedMutex> game_texture_mutex_{};
    SharedRenderFrame active_render_frame_{};
    SharedState render_state_{};
    FreeTrackOutput freetrack_{};
    ControllerAimOutput controller_aim_{};
    ControllerInputOutput controller_input_{};
    bool recenter_key_down_{};
    bool motion_toggle_previous_{};
};

} // namespace a3vr
