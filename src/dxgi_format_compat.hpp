#pragma once

#include <cstdint>
#include <span>

#include <dxgiformat.h>

namespace a3vr {

// D3D11 permits resource copies between typed formats in the same typeless
// format family. OpenXR runtimes commonly expose only the sRGB member while a
// legacy game swapchain uses the UNORM member (or vice versa).
constexpr std::uint32_t dxgi_copy_family(const DXGI_FORMAT format) noexcept {
    switch (format) {
    case DXGI_FORMAT_R8G8B8A8_TYPELESS:
    case DXGI_FORMAT_R8G8B8A8_UNORM:
    case DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
        return 1;
    case DXGI_FORMAT_B8G8R8A8_TYPELESS:
    case DXGI_FORMAT_B8G8R8A8_UNORM:
    case DXGI_FORMAT_B8G8R8A8_UNORM_SRGB:
        return 2;
    case DXGI_FORMAT_B8G8R8X8_TYPELESS:
    case DXGI_FORMAT_B8G8R8X8_UNORM:
    case DXGI_FORMAT_B8G8R8X8_UNORM_SRGB:
        return 3;
    case DXGI_FORMAT_R10G10B10A2_TYPELESS:
    case DXGI_FORMAT_R10G10B10A2_UNORM:
    case DXGI_FORMAT_R10G10B10A2_UINT:
        return 4;
    default:
        return 0;
    }
}

inline std::int64_t choose_openxr_swapchain_format(
    const DXGI_FORMAT source, const std::span<const std::int64_t> supported) noexcept {
    const auto exact = static_cast<std::int64_t>(source);
    for (const auto candidate : supported) {
        if (candidate == exact) return candidate;
    }
    const std::uint32_t family = dxgi_copy_family(source);
    if (family == 0) return 0;
    // Preserve the runtime's preference order among compatible formats.
    for (const auto candidate : supported) {
        if (candidate >= 0 && dxgi_copy_family(
                static_cast<DXGI_FORMAT>(candidate)) == family) {
            return candidate;
        }
    }
    return 0;
}

} // namespace a3vr
