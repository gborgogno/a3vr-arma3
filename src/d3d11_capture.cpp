#include "d3d11_capture.hpp"

#include "shared_state.hpp"

#include <MinHook.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <wrl/client.h>

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <windows.h>

namespace a3vr {
namespace {
using Microsoft::WRL::ComPtr;
using PresentFn = HRESULT(__stdcall*)(IDXGISwapChain*, UINT, UINT);
using ResizeBuffersFn = HRESULT(__stdcall*)(IDXGISwapChain*, UINT, UINT, UINT, DXGI_FORMAT, UINT);

PresentFn original_present{};
ResizeBuffersFn original_resize_buffers{};
std::once_flag install_once;
std::atomic<bool> installed{false};
std::atomic<std::uint64_t> next_generation{1};
std::string install_status{"not started"};
std::mutex resource_mutex;
ComPtr<ID3D11Texture2D> shared_texture;
ComPtr<ID3D11Texture2D> owner_texture;
ComPtr<ID3D11Device> owner_device;
ComPtr<IDXGIKeyedMutex> keyed_mutex;
HANDLE shared_handle{};
IDXGISwapChain* captured_swapchain{};
SharedRenderFrame render_frame{};
SharedState render_state;

void release_shared_texture() {
    std::scoped_lock lock(resource_mutex);
    keyed_mutex.Reset();
    shared_texture.Reset();
    owner_texture.Reset();
    owner_device.Reset();
    shared_handle = nullptr;
    captured_swapchain = nullptr;
    render_frame = {};
}

bool create_shared_texture(IDXGISwapChain* swapchain, ID3D11Texture2D* backbuffer) {
    D3D11_TEXTURE2D_DESC source{};
    backbuffer->GetDesc(&source);
    render_frame.source_pid = GetCurrentProcessId();
    render_frame.width = source.Width;
    render_frame.height = source.Height;
    render_frame.dxgi_format = static_cast<std::uint32_t>(source.Format);
    render_frame.capture_state = 10;
    ComPtr<ID3D11Device> device;
    HRESULT result = swapchain->GetDevice(IID_PPV_ARGS(&device));
    if (FAILED(result)) {
        render_frame.capture_state = 20;
        render_frame.last_hresult = result;
        return false;
    }

    D3D11_TEXTURE2D_DESC desc{};
    desc.Width = source.Width;
    desc.Height = source.Height;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = source.Format;
    desc.SampleDesc = {1, 0};
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_RENDER_TARGET;
    desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;

    ComPtr<IDXGIDevice> dxgi_device;
    ComPtr<IDXGIAdapter> adapter;
    result = device.As(&dxgi_device);
    if (SUCCEEDED(result)) result = dxgi_device->GetAdapter(&adapter);
    D3D_FEATURE_LEVEL feature_level{};
    ComPtr<ID3D11DeviceContext> owner_context;
    if (SUCCEEDED(result)) {
        result = D3D11CreateDevice(adapter.Get(), D3D_DRIVER_TYPE_UNKNOWN, nullptr,
            D3D11_CREATE_DEVICE_BGRA_SUPPORT, nullptr, 0, D3D11_SDK_VERSION,
            &owner_device, &feature_level, &owner_context);
    }
    if (FAILED(result)) {
        render_frame.capture_state = 21;
        render_frame.last_hresult = result;
        return false;
    }

    result = owner_device->CreateTexture2D(&desc, nullptr, &owner_texture);
    if (FAILED(result)) {
        render_frame.capture_state = 22;
        render_frame.last_hresult = result;
        return false;
    }
    ComPtr<IDXGIResource> resource;
    result = owner_texture.As(&resource);
    if (FAILED(result)) {
        render_frame.capture_state = 23;
        render_frame.last_hresult = result;
        return false;
    }
    HANDLE handle{};
    result = resource->GetSharedHandle(&handle);
    if (FAILED(result)) {
        render_frame.capture_state = 24;
        render_frame.last_hresult = result;
        return false;
    }
    ComPtr<ID3D11Texture2D> texture;
    result = device->OpenSharedResource(handle, IID_PPV_ARGS(&texture));
    if (FAILED(result)) {
        render_frame.capture_state = 25;
        render_frame.last_hresult = result;
        return false;
    }
    keyed_mutex.Reset();
    shared_texture = std::move(texture);
    shared_handle = handle;
    captured_swapchain = swapchain;
    render_frame.generation = next_generation.fetch_add(1);
    render_frame.frame_sequence = 0;
    render_frame.shared_handle = reinterpret_cast<std::uint64_t>(handle);
    render_frame.source_pid = GetCurrentProcessId();
    render_frame.width = desc.Width;
    render_frame.height = desc.Height;
    render_frame.dxgi_format = static_cast<std::uint32_t>(desc.Format);
    render_frame.capture_state = 1;
    render_frame.last_hresult = S_OK;
    return true;
}

HRESULT __stdcall hooked_present(IDXGISwapChain* swapchain, UINT sync_interval, UINT flags) {
    {
        std::unique_lock lock(resource_mutex, std::try_to_lock);
        if (lock.owns_lock()) {
            ComPtr<ID3D11Texture2D> backbuffer;
            if (SUCCEEDED(swapchain->GetBuffer(0, IID_PPV_ARGS(&backbuffer)))) {
                D3D11_TEXTURE2D_DESC source{};
                backbuffer->GetDesc(&source);
                const bool changed = captured_swapchain != swapchain || !shared_texture ||
                    render_frame.width != source.Width || render_frame.height != source.Height ||
                    render_frame.dxgi_format != static_cast<std::uint32_t>(source.Format);
                if (changed) {
                    keyed_mutex.Reset();
                    shared_texture.Reset();
                    owner_texture.Reset();
                    owner_device.Reset();
                    shared_handle = nullptr;
                    create_shared_texture(swapchain, backbuffer.Get());
                    render_state.publish_render(render_frame);
                }
                if (shared_texture) {
                    ComPtr<ID3D11Device> device;
                    swapchain->GetDevice(IID_PPV_ARGS(&device));
                    ComPtr<ID3D11DeviceContext> context;
                    if (device) device->GetImmediateContext(&context);
                    if (context) {
                        if (source.SampleDesc.Count > 1) {
                            context->ResolveSubresource(shared_texture.Get(), 0, backbuffer.Get(), 0,
                                                        source.Format);
                        } else {
                            context->CopyResource(shared_texture.Get(), backbuffer.Get());
                        }
                        ++render_frame.frame_sequence;
                        render_frame.capture_state = 3;
                        render_frame.last_hresult = S_OK;
                        render_state.publish_render(render_frame);
                        context->Flush();
                    }
                }
            }
        }
    }
    return original_present(swapchain, sync_interval, flags);
}

HRESULT __stdcall hooked_resize_buffers(IDXGISwapChain* swapchain, UINT count, UINT width,
                                        UINT height, DXGI_FORMAT format, UINT flags) {
    if (captured_swapchain == swapchain) release_shared_texture();
    return original_resize_buffers(swapchain, count, width, height, format, flags);
}

LRESULT CALLBACK dummy_window_proc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    return DefWindowProcW(window, message, wparam, lparam);
}

bool find_swapchain_methods(void*& present, void*& resize) {
    const wchar_t class_name[] = L"A3VR_D3D11_Probe";
    WNDCLASSEXW window_class{sizeof(window_class)};
    window_class.lpfnWndProc = dummy_window_proc;
    window_class.hInstance = GetModuleHandleW(nullptr);
    window_class.lpszClassName = class_name;
    const ATOM atom = RegisterClassExW(&window_class);
    if (atom == 0 && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return false;
    HWND window = CreateWindowExW(0, class_name, L"", WS_OVERLAPPED,
                                  0, 0, 2, 2, nullptr, nullptr,
                                  window_class.hInstance, nullptr);
    if (window == nullptr) return false;

    DXGI_SWAP_CHAIN_DESC desc{};
    desc.BufferDesc.Width = 2;
    desc.BufferDesc.Height = 2;
    desc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = 1;
    desc.OutputWindow = window;
    desc.Windowed = TRUE;
    desc.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
    ComPtr<IDXGISwapChain> swapchain;
    ComPtr<ID3D11Device> device;
    D3D_FEATURE_LEVEL feature_level{};
    ComPtr<ID3D11DeviceContext> context;
    const HRESULT result = D3D11CreateDeviceAndSwapChain(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0, nullptr, 0,
        D3D11_SDK_VERSION, &desc, &swapchain, &device, &feature_level, &context);
    if (SUCCEEDED(result)) {
        void** vtable = *reinterpret_cast<void***>(swapchain.Get());
        present = vtable[8];
        resize = vtable[13];
    }
    DestroyWindow(window);
    UnregisterClassW(class_name, window_class.hInstance);
    return SUCCEEDED(result);
}
} // namespace

bool start_d3d11_capture() {
    std::call_once(install_once, [] {
        void* present{};
        void* resize{};
        if (!find_swapchain_methods(present, resize)) {
            install_status = "error: could not inspect D3D11 swapchain";
            return;
        }
        if (MH_Initialize() != MH_OK ||
            MH_CreateHook(present, &hooked_present,
                          reinterpret_cast<void**>(&original_present)) != MH_OK ||
            MH_CreateHook(resize, &hooked_resize_buffers,
                          reinterpret_cast<void**>(&original_resize_buffers)) != MH_OK ||
            MH_EnableHook(MH_ALL_HOOKS) != MH_OK) {
            install_status = "error: could not install D3D11 hooks";
            return;
        }
        installed = true;
        install_status = "D3D11 capture active";
    });
    return installed.load();
}

const char* d3d11_capture_status() { return install_status.c_str(); }

} // namespace a3vr
