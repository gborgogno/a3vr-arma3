#pragma once

namespace a3vr {

// Installs a non-blocking IDXGISwapChain hook. Safe to call repeatedly.
bool start_d3d11_capture();
const char* d3d11_capture_status();

} // namespace a3vr
