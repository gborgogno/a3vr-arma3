#include "openxr_tracker.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <initializer_list>
#include <sstream>
#include <string_view>
#include <utility>
#include <vector>

#include <dxgi1_2.h>

using Microsoft::WRL::ComPtr;

namespace a3vr {
namespace {

bool xr_ok(const XrResult result) noexcept { return XR_SUCCEEDED(result); }

TrackedPose convert_pose(const XrSpaceLocation& location) {
    const auto flags = location.locationFlags;
    return {
        (flags & XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0,
        (flags & XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0,
        {location.pose.position.x, location.pose.position.y, location.pose.position.z},
        {location.pose.orientation.x, location.pose.orientation.y,
         location.pose.orientation.z, location.pose.orientation.w},
    };
}

TrackedPose convert_pose(const XrPosef& pose, const XrViewStateFlags flags) {
    return {
        (flags & XR_VIEW_STATE_POSITION_VALID_BIT) != 0,
        (flags & XR_VIEW_STATE_ORIENTATION_VALID_BIT) != 0,
        {pose.position.x, pose.position.y, pose.position.z},
        {pose.orientation.x, pose.orientation.y, pose.orientation.z, pose.orientation.w},
    };
}

} // namespace

OpenXrTracker& OpenXrTracker::instance() {
    // Process-lifetime allocation is intentional. Some runtimes (notably Meta)
    // can leave xrWaitFrame blocked while the host process is shutting down.
    // Waiting from a static DLL destructor would then prevent Arma from exiting.
    static OpenXrTracker* tracker = new OpenXrTracker();
    return *tracker;
}

OpenXrTracker::~OpenXrTracker() { stop(); }

bool OpenXrTracker::start() {
    if (worker_running_.load()) {
        return true;
    }
    if (worker_.joinable()) {
        worker_.join();
    }
    stop_requested_.store(false);
    worker_running_.store(true);
    {
        std::scoped_lock lock(data_mutex_);
        status_ = "starting";
    }
    worker_ = std::thread(&OpenXrTracker::worker_main, this);
    return true;
}

void OpenXrTracker::stop() {
    stop_requested_.store(true);
    const XrSession session = session_for_stop_.load();
    if (session != XR_NULL_HANDLE) {
        (void)xrRequestExitSession(session);
    }
    if (worker_.joinable()) {
        worker_.join();
    }
}

TrackingSnapshot OpenXrTracker::snapshot() const {
    std::scoped_lock lock(data_mutex_);
    return snapshot_;
}

std::string OpenXrTracker::status() const {
    std::scoped_lock lock(data_mutex_);
    return status_;
}

void OpenXrTracker::set_status(std::string message) {
    std::scoped_lock lock(data_mutex_);
    status_ = std::move(message);
}

void OpenXrTracker::set_error(std::string message) {
    std::scoped_lock lock(data_mutex_);
    status_ = "error: " + std::move(message);
}

void OpenXrTracker::worker_main() {
    if (!initialize()) {
        shutdown();
        worker_running_.store(false);
        return;
    }

    while (!stop_requested_.load()) {
        poll_events();
        if (session_running_) {
            run_frame();
        } else {
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
        }
    }

    shutdown();
    worker_running_.store(false);
    std::scoped_lock lock(data_mutex_);
    if (!status_.starts_with("error:")) {
        status_ = "stopped";
    }
}

bool OpenXrTracker::initialize() {
    char stereo_mode[16]{};
    const DWORD stereo_mode_size = GetEnvironmentVariableA(
        "A3VR_STEREO_MODE", stereo_mode, static_cast<DWORD>(std::size(stereo_mode)));
    sbs_mode_ = stereo_mode_size > 0 && stereo_mode_size < std::size(stereo_mode) &&
                std::string_view(stereo_mode) == "sbs";
    mono_mode_ = stereo_mode_size > 0 && stereo_mode_size < std::size(stereo_mode) &&
                 std::string_view(stereo_mode) == "mono";
    const auto read_screen_value = [](const char* name, const float fallback,
                                      const float minimum, const float maximum) {
        char value[32]{};
        const DWORD size = GetEnvironmentVariableA(
            name, value, static_cast<DWORD>(std::size(value)));
        if (size == 0 || size >= std::size(value)) return fallback;
        const float parsed = std::strtof(value, nullptr);
        return parsed >= minimum && parsed <= maximum ? parsed : fallback;
    };
    mono_screen_width_ = read_screen_value(
        "A3VR_MONO_SCREEN_WIDTH", 25.4F, 4.0F, 30.0F);
    mono_screen_height_ = read_screen_value(
        "A3VR_MONO_SCREEN_HEIGHT", 14.3F, 2.0F, 20.0F);
    mono_screen_distance_ = read_screen_value(
        "A3VR_MONO_SCREEN_DISTANCE", 5.0F, 2.0F, 20.0F);
    (void)freetrack_.open();
    set_status("initializing: enumerate extensions");
    std::uint32_t extension_count = 0;
    if (!xr_ok(xrEnumerateInstanceExtensionProperties(nullptr, 0, &extension_count, nullptr))) {
        set_error("cannot enumerate OpenXR extensions");
        return false;
    }
    std::vector<XrExtensionProperties> extensions(extension_count, {XR_TYPE_EXTENSION_PROPERTIES});
    if (!xr_ok(xrEnumerateInstanceExtensionProperties(
            nullptr, extension_count, &extension_count, extensions.data()))) {
        set_error("cannot read OpenXR extensions");
        return false;
    }
    const bool has_d3d11 = std::ranges::any_of(extensions, [](const auto& extension) {
        return std::strcmp(extension.extensionName, XR_KHR_D3D11_ENABLE_EXTENSION_NAME) == 0;
    });
    if (!has_d3d11) {
        set_error("active runtime does not expose XR_KHR_D3D11_enable");
        return false;
    }

    const char* enabled_extensions[] = {XR_KHR_D3D11_ENABLE_EXTENSION_NAME};
    set_status("initializing: create instance");
    XrInstanceCreateInfo instance_info{XR_TYPE_INSTANCE_CREATE_INFO};
    strcpy_s(instance_info.applicationInfo.applicationName, "A3VR");
    instance_info.applicationInfo.applicationVersion = 1;
    strcpy_s(instance_info.applicationInfo.engineName, "Real Virtuality 4");
    instance_info.applicationInfo.engineVersion = 1;
    instance_info.applicationInfo.apiVersion = XR_CURRENT_API_VERSION;
    instance_info.enabledExtensionCount = 1;
    instance_info.enabledExtensionNames = enabled_extensions;
    if (!xr_ok(xrCreateInstance(&instance_info, &instance_))) {
        set_error("xrCreateInstance failed; verify the active OpenXR runtime");
        return false;
    }

    XrSystemGetInfo system_info{XR_TYPE_SYSTEM_GET_INFO};
    set_status("initializing: find headset");
    system_info.formFactor = XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY;
    if (!xr_ok(xrGetSystem(instance_, &system_info, &system_id_))) {
        set_error("no OpenXR headset is available");
        return false;
    }

    PFN_xrGetD3D11GraphicsRequirementsKHR get_requirements = nullptr;
    set_status("initializing: graphics requirements");
    if (!xr_ok(xrGetInstanceProcAddr(instance_, "xrGetD3D11GraphicsRequirementsKHR",
            reinterpret_cast<PFN_xrVoidFunction*>(&get_requirements))) || get_requirements == nullptr) {
        set_error("cannot resolve D3D11 OpenXR requirements");
        return false;
    }
    XrGraphicsRequirementsD3D11KHR requirements{XR_TYPE_GRAPHICS_REQUIREMENTS_D3D11_KHR};
    set_status("initializing: D3D11 device");
    if (!xr_ok(get_requirements(instance_, system_id_, &requirements)) ||
        !create_d3d_device(requirements.adapterLuid, requirements.minFeatureLevel)) {
        set_error("cannot create the OpenXR D3D11 device");
        return false;
    }

    XrGraphicsBindingD3D11KHR graphics_binding{XR_TYPE_GRAPHICS_BINDING_D3D11_KHR};
    set_status("initializing: create session");
    graphics_binding.device = d3d_device_.Get();
    XrSessionCreateInfo session_info{XR_TYPE_SESSION_CREATE_INFO};
    session_info.next = &graphics_binding;
    session_info.systemId = system_id_;
    if (!xr_ok(xrCreateSession(instance_, &session_info, &session_))) {
        set_error("xrCreateSession failed");
        return false;
    }
    session_for_stop_.store(session_);

    set_status("initializing: reference spaces");
    XrReferenceSpaceCreateInfo space_info{XR_TYPE_REFERENCE_SPACE_CREATE_INFO};
    space_info.poseInReferenceSpace.orientation.w = 1.0F;
    space_info.referenceSpaceType = XR_REFERENCE_SPACE_TYPE_LOCAL;
    if (!xr_ok(xrCreateReferenceSpace(session_, &space_info, &local_space_))) {
        set_error("cannot create LOCAL reference space");
        return false;
    }
    space_info.referenceSpaceType = XR_REFERENCE_SPACE_TYPE_VIEW;
    if (!xr_ok(xrCreateReferenceSpace(session_, &space_info, &view_space_))) {
        set_error("cannot create VIEW reference space");
        return false;
    }
    set_status("initializing: actions");
    if (!create_actions()) {
        return false;
    }

    std::scoped_lock lock(data_mutex_);
    status_ = "waiting for headset";
    return true;
}

bool OpenXrTracker::create_d3d_device(const LUID& adapter_luid, const D3D_FEATURE_LEVEL minimum_level) {
    ComPtr<IDXGIFactory1> factory;
    if (FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) {
        return false;
    }
    ComPtr<IDXGIAdapter1> selected;
    for (UINT index = 0; ; ++index) {
        ComPtr<IDXGIAdapter1> candidate;
        if (factory->EnumAdapters1(index, &candidate) == DXGI_ERROR_NOT_FOUND) {
            break;
        }
        DXGI_ADAPTER_DESC1 description{};
        if (SUCCEEDED(candidate->GetDesc1(&description)) &&
            description.AdapterLuid.HighPart == adapter_luid.HighPart &&
            description.AdapterLuid.LowPart == adapter_luid.LowPart) {
            selected = candidate;
            break;
        }
    }
    if (!selected) {
        return false;
    }

    constexpr std::array levels{
        D3D_FEATURE_LEVEL_12_1, D3D_FEATURE_LEVEL_12_0, D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0,
    };
    const auto first = std::find(levels.begin(), levels.end(), minimum_level);
    if (first == levels.end()) {
        return false;
    }
    D3D_FEATURE_LEVEL created_level{};
    return SUCCEEDED(D3D11CreateDevice(selected.Get(), D3D_DRIVER_TYPE_UNKNOWN, nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT, &*first,
        static_cast<UINT>(std::distance(first, levels.end())), D3D11_SDK_VERSION,
        &d3d_device_, &created_level, &d3d_context_));
}

bool OpenXrTracker::create_actions() {
    xrStringToPath(instance_, "/user/hand/left", &hand_paths_[0]);
    xrStringToPath(instance_, "/user/hand/right", &hand_paths_[1]);

    XrActionSetCreateInfo set_info{XR_TYPE_ACTION_SET_CREATE_INFO};
    strcpy_s(set_info.actionSetName, "gameplay");
    strcpy_s(set_info.localizedActionSetName, "A3VR Gameplay");
    if (!xr_ok(xrCreateActionSet(instance_, &set_info, &action_set_))) {
        set_error("cannot create action set");
        return false;
    }

    auto create_action = [&](const XrActionType type, const char* name,
                             const char* localized_name, const XrPath* subactions,
                             const std::uint32_t subaction_count,
                             XrAction& action) -> bool {
        XrActionCreateInfo info{XR_TYPE_ACTION_CREATE_INFO};
        info.actionType = type;
        strcpy_s(info.actionName, name);
        strcpy_s(info.localizedActionName, localized_name);
        info.countSubactionPaths = subaction_count;
        info.subactionPaths = subactions;
        return xr_ok(xrCreateAction(action_set_, &info, &action));
    };
    if (!create_action(XR_ACTION_TYPE_POSE_INPUT, "hand_pose", "Hand pose",
                       hand_paths_.data(), 2, hand_pose_action_) ||
        !create_action(XR_ACTION_TYPE_FLOAT_INPUT, "fire", "Fire",
                       &hand_paths_[1], 1, fire_action_) ||
        !create_action(XR_ACTION_TYPE_FLOAT_INPUT, "aim", "Aim down sights",
                       &hand_paths_[1], 1, aim_action_) ||
        !create_action(XR_ACTION_TYPE_FLOAT_INPUT, "left_trigger", "Left index curl",
                       &hand_paths_[0], 1, left_trigger_action_) ||
        !create_action(XR_ACTION_TYPE_FLOAT_INPUT, "left_squeeze", "Left grip curl",
                       &hand_paths_[0], 1, left_squeeze_action_) ||
        !create_action(XR_ACTION_TYPE_BOOLEAN_INPUT, "left_thumb_touch", "Left thumb touch",
                       &hand_paths_[0], 1, left_thumb_touch_action_) ||
        !create_action(XR_ACTION_TYPE_VECTOR2F_INPUT, "move", "Move",
                       &hand_paths_[0], 1, move_action_) ||
        !create_action(XR_ACTION_TYPE_FLOAT_INPUT, "move_x", "Move horizontal",
                       &hand_paths_[0], 1, move_x_action_) ||
        !create_action(XR_ACTION_TYPE_FLOAT_INPUT, "move_y", "Move vertical",
                       &hand_paths_[0], 1, move_y_action_) ||
        !create_action(XR_ACTION_TYPE_VECTOR2F_INPUT, "right_move", "Right stick move",
                       &hand_paths_[1], 1, right_move_action_) ||
        !create_action(XR_ACTION_TYPE_FLOAT_INPUT, "right_move_x", "Right move horizontal",
                       &hand_paths_[1], 1, right_move_x_action_) ||
        !create_action(XR_ACTION_TYPE_FLOAT_INPUT, "right_move_y", "Right move vertical",
                       &hand_paths_[1], 1, right_move_y_action_) ||
        !create_action(XR_ACTION_TYPE_BOOLEAN_INPUT, "sprint", "Sprint",
                       &hand_paths_[0], 1, sprint_action_) ||
        !create_action(XR_ACTION_TYPE_BOOLEAN_INPUT, "reload", "Reload",
                       &hand_paths_[1], 1, reload_action_) ||
        !create_action(XR_ACTION_TYPE_BOOLEAN_INPUT, "fire_mode", "Fire mode",
                       &hand_paths_[1], 1, fire_mode_action_) ||
        !create_action(XR_ACTION_TYPE_BOOLEAN_INPUT, "swap_weapon", "Swap weapon",
                       &hand_paths_[0], 1, swap_weapon_action_) ||
        !create_action(XR_ACTION_TYPE_BOOLEAN_INPUT, "vault", "Vault or step over",
                       &hand_paths_[1], 1, vault_action_) ||
        !create_action(XR_ACTION_TYPE_BOOLEAN_INPUT, "interact", "Interact",
                       &hand_paths_[0], 1, interact_action_)) {
        set_error("cannot create controller actions");
        return false;
    }

    auto suggest_profile = [&](const char* profile_name,
                               const std::initializer_list<std::pair<XrAction, const char*>> paths) {
        XrPath profile{};
        if (!xr_ok(xrStringToPath(instance_, profile_name, &profile))) return;
        std::vector<XrActionSuggestedBinding> bindings;
        bindings.reserve(paths.size());
        for (const auto& [action, path_name] : paths) {
            XrPath path{};
            if (xr_ok(xrStringToPath(instance_, path_name, &path))) {
                bindings.push_back({action, path});
            }
        }
        XrInteractionProfileSuggestedBinding suggestion{
            XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING};
        suggestion.interactionProfile = profile;
        suggestion.suggestedBindings = bindings.data();
        suggestion.countSuggestedBindings = static_cast<std::uint32_t>(bindings.size());
        (void)xrSuggestInteractionProfileBindings(instance_, &suggestion);
    };

    suggest_profile("/interaction_profiles/khr/simple_controller", {
        {hand_pose_action_, "/user/hand/left/input/aim/pose"},
        {hand_pose_action_, "/user/hand/right/input/aim/pose"},
    });
    suggest_profile("/interaction_profiles/oculus/touch_controller", {
        {hand_pose_action_, "/user/hand/left/input/aim/pose"},
        {hand_pose_action_, "/user/hand/right/input/aim/pose"},
        {fire_action_, "/user/hand/right/input/trigger/value"},
        {aim_action_, "/user/hand/right/input/squeeze/value"},
        {left_trigger_action_, "/user/hand/left/input/trigger/value"},
        {left_squeeze_action_, "/user/hand/left/input/squeeze/value"},
        {left_thumb_touch_action_, "/user/hand/left/input/thumbstick/touch"},
        {move_action_, "/user/hand/left/input/thumbstick"},
        {move_x_action_, "/user/hand/left/input/thumbstick/x"},
        {move_y_action_, "/user/hand/left/input/thumbstick/y"},
        {right_move_action_, "/user/hand/right/input/thumbstick"},
        {right_move_x_action_, "/user/hand/right/input/thumbstick/x"},
        {right_move_y_action_, "/user/hand/right/input/thumbstick/y"},
        {sprint_action_, "/user/hand/left/input/thumbstick/click"},
        {reload_action_, "/user/hand/right/input/a/click"},
        {fire_mode_action_, "/user/hand/right/input/thumbstick/click"},
        {swap_weapon_action_, "/user/hand/left/input/y/click"},
        {vault_action_, "/user/hand/right/input/b/click"},
        {interact_action_, "/user/hand/left/input/x/click"},
    });
    suggest_profile("/interaction_profiles/valve/index_controller", {
        {hand_pose_action_, "/user/hand/left/input/aim/pose"},
        {hand_pose_action_, "/user/hand/right/input/aim/pose"},
        {fire_action_, "/user/hand/right/input/trigger/value"},
        {aim_action_, "/user/hand/right/input/squeeze/value"},
        {left_trigger_action_, "/user/hand/left/input/trigger/value"},
        {left_squeeze_action_, "/user/hand/left/input/squeeze/value"},
        {left_thumb_touch_action_, "/user/hand/left/input/thumbstick/touch"},
        {move_action_, "/user/hand/left/input/thumbstick"},
        {move_x_action_, "/user/hand/left/input/thumbstick/x"},
        {move_y_action_, "/user/hand/left/input/thumbstick/y"},
        {right_move_action_, "/user/hand/right/input/thumbstick"},
        {right_move_x_action_, "/user/hand/right/input/thumbstick/x"},
        {right_move_y_action_, "/user/hand/right/input/thumbstick/y"},
        {sprint_action_, "/user/hand/left/input/thumbstick/click"},
        {reload_action_, "/user/hand/right/input/a/click"},
        {fire_mode_action_, "/user/hand/right/input/thumbstick/click"},
        {swap_weapon_action_, "/user/hand/left/input/b/click"},
        {vault_action_, "/user/hand/right/input/b/click"},
        {interact_action_, "/user/hand/left/input/a/click"},
    });
    suggest_profile("/interaction_profiles/microsoft/motion_controller", {
        {hand_pose_action_, "/user/hand/left/input/aim/pose"},
        {hand_pose_action_, "/user/hand/right/input/aim/pose"},
        {fire_action_, "/user/hand/right/input/trigger/value"},
        {left_trigger_action_, "/user/hand/left/input/trigger/value"},
        {move_action_, "/user/hand/left/input/thumbstick"},
        {move_x_action_, "/user/hand/left/input/thumbstick/x"},
        {move_y_action_, "/user/hand/left/input/thumbstick/y"},
        {right_move_action_, "/user/hand/right/input/thumbstick"},
        {right_move_x_action_, "/user/hand/right/input/thumbstick/x"},
        {right_move_y_action_, "/user/hand/right/input/thumbstick/y"},
        {sprint_action_, "/user/hand/left/input/thumbstick/click"},
        {reload_action_, "/user/hand/right/input/menu/click"},
        {fire_mode_action_, "/user/hand/right/input/thumbstick/click"},
        {interact_action_, "/user/hand/left/input/menu/click"},
    });

    for (std::size_t index = 0; index < hand_spaces_.size(); ++index) {
        XrActionSpaceCreateInfo action_space_info{XR_TYPE_ACTION_SPACE_CREATE_INFO};
        action_space_info.action = hand_pose_action_;
        action_space_info.subactionPath = hand_paths_[index];
        action_space_info.poseInActionSpace.orientation.w = 1.0F;
        if (!xr_ok(xrCreateActionSpace(session_, &action_space_info, &hand_spaces_[index]))) {
            set_error("cannot create hand action space");
            return false;
        }
    }

    XrSessionActionSetsAttachInfo attach_info{XR_TYPE_SESSION_ACTION_SETS_ATTACH_INFO};
    attach_info.countActionSets = 1;
    attach_info.actionSets = &action_set_;
    if (!xr_ok(xrAttachSessionActionSets(session_, &attach_info))) {
        set_error("cannot attach action set");
        return false;
    }
    return true;
}

void OpenXrTracker::destroy_render_resources() {
    game_texture_mutex_.Reset();
    game_texture_.Reset();
    for (auto& eye : eye_swapchains_) {
        eye.images.clear();
        if (eye.handle != XR_NULL_HANDLE) xrDestroySwapchain(eye.handle);
        eye.handle = XR_NULL_HANDLE;
    }
    active_render_frame_ = {};
}

bool OpenXrTracker::create_render_swapchains(const SharedRenderFrame& frame) {
    std::uint32_t format_count{};
    if (!xr_ok(xrEnumerateSwapchainFormats(session_, 0, &format_count, nullptr))) return false;
    std::vector<std::int64_t> formats(format_count);
    if (!xr_ok(xrEnumerateSwapchainFormats(session_, format_count, &format_count,
                                           formats.data()))) return false;
    const auto format = static_cast<std::int64_t>(frame.dxgi_format);
    if (std::ranges::find(formats, format) == formats.end()) {
        set_error("Arma backbuffer format is not accepted by the OpenXR runtime");
        return false;
    }

    for (auto& eye : eye_swapchains_) {
        XrSwapchainCreateInfo info{XR_TYPE_SWAPCHAIN_CREATE_INFO};
        info.usageFlags = XR_SWAPCHAIN_USAGE_COLOR_ATTACHMENT_BIT |
                          XR_SWAPCHAIN_USAGE_SAMPLED_BIT |
                          XR_SWAPCHAIN_USAGE_TRANSFER_DST_BIT;
        info.format = format;
        info.sampleCount = 1;
        info.width = sbs_mode_ ? frame.width / 2 : frame.width;
        info.height = frame.height;
        info.faceCount = 1;
        info.arraySize = 1;
        info.mipCount = 1;
        if (!xr_ok(xrCreateSwapchain(session_, &info, &eye.handle))) return false;
        std::uint32_t image_count{};
        if (!xr_ok(xrEnumerateSwapchainImages(eye.handle, 0, &image_count, nullptr))) return false;
        eye.images.assign(image_count, {XR_TYPE_SWAPCHAIN_IMAGE_D3D11_KHR});
        if (!xr_ok(xrEnumerateSwapchainImages(
                eye.handle, image_count, &image_count,
                reinterpret_cast<XrSwapchainImageBaseHeader*>(eye.images.data())))) return false;
    }
    return true;
}

bool OpenXrTracker::update_shared_render_source() {
    SharedRenderFrame frame{};
    if (!render_state_.read_render(frame) || frame.shared_handle == 0 || frame.source_pid == 0)
        return game_texture_ != nullptr;
    // Never replace a compositor-visible texture with a handle that has not
    // received a complete game frame yet. Startup/loading swapchain handovers
    // publish state 1 briefly; accepting those handles caused the headset to
    // alternate between valid video and an empty layer.
    if (frame.capture_state != 3 || frame.frame_sequence == 0)
        return game_texture_ != nullptr;
    if (game_texture_ && frame.source_pid == active_render_frame_.source_pid &&
        frame.shared_handle == active_render_frame_.shared_handle &&
        frame.width == active_render_frame_.width && frame.height == active_render_frame_.height &&
        frame.dxgi_format == active_render_frame_.dxgi_format) return true;

    const bool first_frame_from_game = active_render_frame_.source_pid == 0 ||
        frame.source_pid != active_render_frame_.source_pid;
    destroy_render_resources();
    ComPtr<ID3D11Texture2D> texture;
    const HRESULT opened = d3d_device_->OpenSharedResource(
        reinterpret_cast<HANDLE>(static_cast<std::uintptr_t>(frame.shared_handle)),
        IID_PPV_ARGS(&texture));
    if (FAILED(opened)) return false;
    (void)texture.As(&game_texture_mutex_);
    game_texture_ = std::move(texture);
    if (!create_render_swapchains(frame)) {
        destroy_render_resources();
        return false;
    }
    active_render_frame_ = frame;
    // The runtime starts before Arma so it can expose FreeTrack during device
    // enumeration. Do not keep the arbitrary headset pose sampled while the
    // game was loading (often the headset is on a desk then). The first real
    // Arma backbuffer is the stable, user-facing recenter point.
    if (first_frame_from_game) freetrack_.recenter();
    set_status(mono_mode_ ? "tracking + comfort mono" :
               (sbs_mode_ ? "tracking + depth SBS" : "tracking; video mode required"));
    return true;
}

void OpenXrTracker::poll_events() {
    XrEventDataBuffer event{XR_TYPE_EVENT_DATA_BUFFER};
    while (xrPollEvent(instance_, &event) == XR_SUCCESS) {
        if (event.type == XR_TYPE_EVENT_DATA_SESSION_STATE_CHANGED) {
            const auto& changed = reinterpret_cast<const XrEventDataSessionStateChanged&>(event);
            session_state_ = changed.state;
            if (session_state_ == XR_SESSION_STATE_READY && !session_running_) {
                XrSessionBeginInfo begin_info{XR_TYPE_SESSION_BEGIN_INFO};
                begin_info.primaryViewConfigurationType = XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO;
                if (xr_ok(xrBeginSession(session_, &begin_info))) {
                    session_running_ = true;
                    std::scoped_lock lock(data_mutex_);
                    status_ = "tracking";
                }
            } else if (session_state_ == XR_SESSION_STATE_STOPPING && session_running_) {
                (void)xrEndSession(session_);
                session_running_ = false;
            } else if (session_state_ == XR_SESSION_STATE_EXITING ||
                       session_state_ == XR_SESSION_STATE_LOSS_PENDING) {
                stop_requested_.store(true);
            }
        }
        event = {XR_TYPE_EVENT_DATA_BUFFER};
    }
}

void OpenXrTracker::run_frame() {
    XrFrameWaitInfo wait_info{XR_TYPE_FRAME_WAIT_INFO};
    XrFrameState frame_state{XR_TYPE_FRAME_STATE};
    if (!xr_ok(xrWaitFrame(session_, &wait_info, &frame_state))) {
        return;
    }
    XrFrameBeginInfo begin_info{XR_TYPE_FRAME_BEGIN_INFO};
    if (!xr_ok(xrBeginFrame(session_, &begin_info))) {
        return;
    }

    TrackingSnapshot next{};
    {
        std::scoped_lock lock(data_mutex_);
        next.sequence = snapshot_.sequence + 1;
    }
    next.predicted_display_time = frame_state.predictedDisplayTime;
    next.session_state = static_cast<std::int32_t>(session_state_);
    next.session_running = session_running_;

    bool recenter_requested = false;
    XrSpaceLocation head_location{XR_TYPE_SPACE_LOCATION};
    if (xr_ok(xrLocateSpace(view_space_, local_space_, frame_state.predictedDisplayTime, &head_location))) {
        next.head = convert_pose(head_location);
        const bool recenter_key_down = (GetAsyncKeyState(VK_F8) & 0x8000) != 0;
        if (recenter_key_down && !recenter_key_down_) {
            freetrack_.recenter();
            recenter_requested = true;
        }
        recenter_key_down_ = recenter_key_down;
        freetrack_.publish(next.head);
    }

    ControllerInputState controller_input{};
    const XrActiveActionSet active_set{action_set_, XR_NULL_PATH};
    XrActionsSyncInfo sync_info{XR_TYPE_ACTIONS_SYNC_INFO};
    sync_info.countActiveActionSets = 1;
    sync_info.activeActionSets = &active_set;
    if (xr_ok(xrSyncActions(session_, &sync_info))) {
        for (std::size_t index = 0; index < hand_spaces_.size(); ++index) {
            XrActionStateGetInfo state_info{XR_TYPE_ACTION_STATE_GET_INFO};
            state_info.action = hand_pose_action_;
            state_info.subactionPath = hand_paths_[index];
            XrActionStatePose state{XR_TYPE_ACTION_STATE_POSE};
            if (xr_ok(xrGetActionStatePose(session_, &state_info, &state)) && state.isActive) {
                XrSpaceLocation location{XR_TYPE_SPACE_LOCATION};
                if (xr_ok(xrLocateSpace(hand_spaces_[index], local_space_,
                        frame_state.predictedDisplayTime, &location))) {
                    (index == 0 ? next.left_hand : next.right_hand) = convert_pose(location);
                }
            }
        }

        auto read_boolean = [&](const XrAction action, const XrPath hand) {
            XrActionStateGetInfo info{XR_TYPE_ACTION_STATE_GET_INFO};
            info.action = action;
            info.subactionPath = hand;
            XrActionStateBoolean state{XR_TYPE_ACTION_STATE_BOOLEAN};
            return xr_ok(xrGetActionStateBoolean(session_, &info, &state)) &&
                   state.isActive && state.currentState;
        };
        auto read_float = [&](const XrAction action, const XrPath hand) {
            XrActionStateGetInfo info{XR_TYPE_ACTION_STATE_GET_INFO};
            info.action = action;
            info.subactionPath = hand;
            XrActionStateFloat state{XR_TYPE_ACTION_STATE_FLOAT};
            return xr_ok(xrGetActionStateFloat(session_, &info, &state)) && state.isActive
                ? state.currentState : 0.0F;
        };
        XrActionStateGetInfo move_info{XR_TYPE_ACTION_STATE_GET_INFO};
        move_info.action = move_action_;
        move_info.subactionPath = hand_paths_[0];
        XrActionStateVector2f move_state{XR_TYPE_ACTION_STATE_VECTOR2F};
        if (xr_ok(xrGetActionStateVector2f(session_, &move_info, &move_state)) &&
            move_state.isActive) {
            controller_input.move_x = move_state.currentState.x;
            controller_input.move_y = move_state.currentState.y;
        }
        const float component_x = read_float(move_x_action_, hand_paths_[0]);
        const float component_y = read_float(move_y_action_, hand_paths_[0]);
        if (std::abs(component_x) > std::abs(controller_input.move_x)) {
            controller_input.move_x = component_x;
        }
        if (std::abs(component_y) > std::abs(controller_input.move_y)) {
            controller_input.move_y = component_y;
        }
        float right_x{};
        float right_y{};
        XrActionStateGetInfo right_move_info{XR_TYPE_ACTION_STATE_GET_INFO};
        right_move_info.action = right_move_action_;
        right_move_info.subactionPath = hand_paths_[1];
        XrActionStateVector2f right_move_state{XR_TYPE_ACTION_STATE_VECTOR2F};
        if (xr_ok(xrGetActionStateVector2f(session_, &right_move_info,
                                           &right_move_state)) &&
            right_move_state.isActive) {
            right_x = right_move_state.currentState.x;
            right_y = right_move_state.currentState.y;
        }
        const float right_component_x = read_float(right_move_x_action_, hand_paths_[1]);
        const float right_component_y = read_float(right_move_y_action_, hand_paths_[1]);
        if (std::abs(right_component_x) > std::abs(right_x)) right_x = right_component_x;
        if (std::abs(right_component_y) > std::abs(right_y)) right_y = right_component_y;
        controller_input.turn_x = right_x;
        controller_input.turn_y = right_y;
        controller_input.fire = read_float(fire_action_, hand_paths_[1]) >= 0.55F;
        controller_input.aim = read_float(aim_action_, hand_paths_[1]) >= 0.55F;
        controller_input.sprint = read_boolean(sprint_action_, hand_paths_[0]) ||
            std::hypot(controller_input.move_x, controller_input.move_y) >= 0.85F;
        controller_input.reload = read_boolean(reload_action_, hand_paths_[1]);
        controller_input.fire_mode = read_boolean(fire_mode_action_, hand_paths_[1]);
        controller_input.swap_weapon = read_boolean(swap_weapon_action_, hand_paths_[0]);
        controller_input.vault = read_boolean(vault_action_, hand_paths_[1]);
        controller_input.interact = read_boolean(interact_action_, hand_paths_[0]);
        const float left_index = std::clamp(
            read_float(left_trigger_action_, hand_paths_[0]), 0.0F, 1.0F);
        const float left_grip = std::clamp(
            read_float(left_squeeze_action_, hand_paths_[0]), 0.0F, 1.0F);
        const float left_thumb = read_boolean(
            left_thumb_touch_action_, hand_paths_[0]) ? 1.0F : 0.0F;
        next.left_finger_curls = {
            left_thumb, left_index, left_grip, left_grip, left_grip};
    }
    next.controller_move_x = controller_input.move_x;
    next.controller_move_y = controller_input.move_y;
    next.controller_turn_x = controller_input.turn_x;
    next.controller_turn_y = controller_input.turn_y;
    next.controller_buttons =
        (controller_input.fire ? 1U : 0U) |
        (controller_input.aim ? 2U : 0U) |
        (controller_input.sprint ? 4U : 0U) |
        (controller_input.reload ? 8U : 0U) |
        (controller_input.fire_mode ? 16U : 0U) |
        (controller_input.swap_weapon ? 32U : 0U) |
        (controller_input.interact ? 64U : 0U) |
        (controller_input.vault ? 128U : 0U);
    controller_aim_.update(next.right_hand, next.head, active_render_frame_.source_pid,
                           recenter_requested);
    controller_input_.update(controller_input, active_render_frame_.source_pid);

    XrViewLocateInfo view_info{XR_TYPE_VIEW_LOCATE_INFO};
    view_info.viewConfigurationType = XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO;
    view_info.displayTime = frame_state.predictedDisplayTime;
    view_info.space = local_space_;
    XrViewState view_state{XR_TYPE_VIEW_STATE};
    std::array<XrView, 2> views{{{XR_TYPE_VIEW}, {XR_TYPE_VIEW}}};
    std::uint32_t view_count = 0;
    if (xr_ok(xrLocateViews(session_, &view_info, &view_state,
            static_cast<std::uint32_t>(views.size()), &view_count, views.data()))) {
        for (std::size_t index = 0; index < std::min<std::size_t>(view_count, views.size()); ++index) {
            next.eyes[index].pose = convert_pose(views[index].pose, view_state.viewStateFlags);
            next.eyes[index].fov = {views[index].fov.angleLeft, views[index].fov.angleRight,
                                    views[index].fov.angleUp, views[index].fov.angleDown};
        }
    }

    // Arma already rotates/translates its camera from the FreeTrack sample.
    // Submit the finished image in head-relative view space so the compositor
    // does not interpret that same motion a second time as a world-space view.
    XrViewLocateInfo layer_view_info = view_info;
    layer_view_info.space = view_space_;
    XrViewState layer_view_state{XR_TYPE_VIEW_STATE};
    std::array<XrView, 2> layer_views{{{XR_TYPE_VIEW}, {XR_TYPE_VIEW}}};
    std::uint32_t layer_view_count = 0;
    const bool layer_views_valid = xr_ok(xrLocateViews(
        session_, &layer_view_info, &layer_view_state,
        static_cast<std::uint32_t>(layer_views.size()), &layer_view_count,
        layer_views.data())) &&
        layer_view_count == static_cast<std::uint32_t>(layer_views.size());

    XrFovf common_layer_fov{};
    if (layer_views_valid) {
        const float horizontal_half_angle = 0.25F * (
            std::abs(layer_views[0].fov.angleLeft) +
            std::abs(layer_views[0].fov.angleRight) +
            std::abs(layer_views[1].fov.angleLeft) +
            std::abs(layer_views[1].fov.angleRight));
        const float vertical_half_angle = 0.25F * (
            std::abs(layer_views[0].fov.angleUp) +
            std::abs(layer_views[0].fov.angleDown) +
            std::abs(layer_views[1].fov.angleUp) +
            std::abs(layer_views[1].fov.angleDown));
        common_layer_fov = {-horizontal_half_angle, horizontal_half_angle,
                            vertical_half_angle, -vertical_half_angle};
    }

    {
        std::scoped_lock lock(data_mutex_);
        snapshot_ = next;
    }

    std::array<XrCompositionLayerProjectionView, 2> projection_views{{
        {XR_TYPE_COMPOSITION_LAYER_PROJECTION_VIEW},
        {XR_TYPE_COMPOSITION_LAYER_PROJECTION_VIEW},
    }};
    XrCompositionLayerProjection projection{XR_TYPE_COMPOSITION_LAYER_PROJECTION};
    XrCompositionLayerQuad mono_quad{XR_TYPE_COMPOSITION_LAYER_QUAD};
    const XrCompositionLayerBaseHeader* submitted_layer = nullptr;
    bool submitted = false;
    const bool has_render_source = (sbs_mode_ || mono_mode_) && frame_state.shouldRender &&
        (!sbs_mode_ || layer_views_valid) &&
        update_shared_render_source() && game_texture_;
    const bool acquired = has_render_source && (!game_texture_mutex_ ||
        game_texture_mutex_->AcquireSync(1, 0) == S_OK);
    if (acquired) {
        bool copied_all = true;
        const std::size_t target_count = mono_mode_ ? 1U : eye_swapchains_.size();
        for (std::size_t index = 0; index < target_count; ++index) {
            auto& eye = eye_swapchains_[index];
            std::uint32_t image_index{};
            XrSwapchainImageAcquireInfo acquire{XR_TYPE_SWAPCHAIN_IMAGE_ACQUIRE_INFO};
            if (!xr_ok(xrAcquireSwapchainImage(eye.handle, &acquire, &image_index))) {
                copied_all = false;
                break;
            }
            XrSwapchainImageWaitInfo wait{XR_TYPE_SWAPCHAIN_IMAGE_WAIT_INFO};
            wait.timeout = 5'000'000;
            if (!xr_ok(xrWaitSwapchainImage(eye.handle, &wait))) {
                XrSwapchainImageReleaseInfo release{XR_TYPE_SWAPCHAIN_IMAGE_RELEASE_INFO};
                (void)xrReleaseSwapchainImage(eye.handle, &release);
                copied_all = false;
                break;
            }
            const std::uint32_t eye_width = mono_mode_
                ? active_render_frame_.width
                : active_render_frame_.width / 2;
            const std::uint32_t source_left = mono_mode_ ? 0U :
                static_cast<std::uint32_t>(index) * eye_width;
            const D3D11_BOX source_box{
                static_cast<UINT>(source_left), 0, 0,
                static_cast<UINT>(source_left + eye_width),
                active_render_frame_.height, 1};
            d3d_context_->CopySubresourceRegion(eye.images[image_index].texture, 0,
                                                0, 0, 0, game_texture_.Get(), 0,
                                                &source_box);
            XrSwapchainImageReleaseInfo release{XR_TYPE_SWAPCHAIN_IMAGE_RELEASE_INFO};
            (void)xrReleaseSwapchainImage(eye.handle, &release);
            if (!mono_mode_) {
                auto& projection_view = projection_views[index];
                projection_view.pose.orientation = {0.0F, 0.0F, 0.0F, 1.0F};
                projection_view.pose.position = {
                    layer_views[index].pose.position.x, 0.0F, 0.0F};
                projection_view.fov = common_layer_fov;
                projection_view.subImage.swapchain = eye.handle;
                projection_view.subImage.imageRect.offset = {0, 0};
                projection_view.subImage.imageRect.extent = {
                    static_cast<std::int32_t>(eye_width),
                    static_cast<std::int32_t>(active_render_frame_.height)};
                projection_view.subImage.imageArrayIndex = 0;
            }
        }
        if (game_texture_mutex_) game_texture_mutex_->ReleaseSync(0);
        if (copied_all) {
            if (mono_mode_) {
                // One compositor-owned surface is shared by both eyes. Keep
                // the exact 25.4 x 14.3 geometry used by the protected v9
                // stable runtime: its fixed dimensions were the user-validated
                // comfort baseline. Do not derive height from the current game
                // backbuffer or mutate this profile with weapon experiments.
                mono_quad.space = view_space_;
                mono_quad.eyeVisibility = XR_EYE_VISIBILITY_BOTH;
                mono_quad.pose.orientation = {0.0F, 0.0F, 0.0F, 1.0F};
                mono_quad.pose.position = {0.0F, 0.0F, -mono_screen_distance_};
                mono_quad.size = {mono_screen_width_, mono_screen_height_};
                mono_quad.subImage.swapchain = eye_swapchains_[0].handle;
                mono_quad.subImage.imageRect.offset = {0, 0};
                mono_quad.subImage.imageRect.extent = {
                    static_cast<std::int32_t>(active_render_frame_.width),
                    static_cast<std::int32_t>(active_render_frame_.height)};
                mono_quad.subImage.imageArrayIndex = 0;
                submitted_layer = reinterpret_cast<const XrCompositionLayerBaseHeader*>(
                    &mono_quad);
            } else {
                projection.space = view_space_;
                projection.viewCount = static_cast<std::uint32_t>(projection_views.size());
                projection.views = projection_views.data();
                submitted_layer = reinterpret_cast<const XrCompositionLayerBaseHeader*>(
                    &projection);
            }
            submitted = true;
        }
    }

    const XrCompositionLayerBaseHeader* layers[] = {submitted_layer};
    XrFrameEndInfo end_info{XR_TYPE_FRAME_END_INFO};
    end_info.displayTime = frame_state.predictedDisplayTime;
    end_info.environmentBlendMode = XR_ENVIRONMENT_BLEND_MODE_OPAQUE;
    end_info.layerCount = submitted ? 1U : 0U;
    end_info.layers = submitted ? layers : nullptr;
    (void)xrEndFrame(session_, &end_info);
}

void OpenXrTracker::shutdown() {
    controller_input_.release_all();
    if (session_running_ && session_ != XR_NULL_HANDLE) {
        (void)xrEndSession(session_);
    }
    session_running_ = false;
    destroy_render_resources();
    for (auto& space : hand_spaces_) {
        if (space != XR_NULL_HANDLE) xrDestroySpace(space);
        space = XR_NULL_HANDLE;
    }
    if (view_space_ != XR_NULL_HANDLE) xrDestroySpace(view_space_);
    if (local_space_ != XR_NULL_HANDLE) xrDestroySpace(local_space_);
    const std::array actions{
        hand_pose_action_, fire_action_, aim_action_, left_trigger_action_,
        left_squeeze_action_, left_thumb_touch_action_, move_action_, move_x_action_,
        move_y_action_, right_move_action_, right_move_x_action_,
        right_move_y_action_, sprint_action_,
        reload_action_, fire_mode_action_, swap_weapon_action_, interact_action_,
        vault_action_,
    };
    for (const XrAction action : actions) {
        if (action != XR_NULL_HANDLE) xrDestroyAction(action);
    }
    if (action_set_ != XR_NULL_HANDLE) xrDestroyActionSet(action_set_);
    if (session_ != XR_NULL_HANDLE) xrDestroySession(session_);
    session_for_stop_.store(XR_NULL_HANDLE);
    if (instance_ != XR_NULL_HANDLE) xrDestroyInstance(instance_);
    view_space_ = local_space_ = XR_NULL_HANDLE;
    hand_pose_action_ = fire_action_ = aim_action_ = left_trigger_action_ =
        left_squeeze_action_ = left_thumb_touch_action_ = move_action_ = XR_NULL_HANDLE;
    move_x_action_ = move_y_action_ = XR_NULL_HANDLE;
    right_move_action_ = right_move_x_action_ = right_move_y_action_ = XR_NULL_HANDLE;
    sprint_action_ = reload_action_ = fire_mode_action_ = XR_NULL_HANDLE;
    swap_weapon_action_ = interact_action_ = XR_NULL_HANDLE;
    vault_action_ = XR_NULL_HANDLE;
    action_set_ = XR_NULL_HANDLE;
    session_ = XR_NULL_HANDLE;
    instance_ = XR_NULL_HANDLE;
    d3d_context_.Reset();
    d3d_device_.Reset();
    freetrack_.close();
}

} // namespace a3vr
