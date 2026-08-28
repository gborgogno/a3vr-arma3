cmake_minimum_required(VERSION 3.24)

project(A3VR VERSION 17.2.0 LANGUAGES C CXX)

if(NOT WIN32 OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "A3VR currently requires 64-bit Windows.")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(FetchContent)
set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(BUILD_CONFORMANCE_TESTS OFF CACHE BOOL "" FORCE)
set(BUILD_API_LAYERS OFF CACHE BOOL "" FORCE)
set(BUILD_LOADER ON CACHE BOOL "" FORCE)
set(DYNAMIC_LOADER OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
    openxr_sdk
    GIT_REPOSITORY https://github.com/KhronosGroup/OpenXR-SDK.git
    GIT_TAG 00678df64b49ad878a8e882af933c28518cafd1c
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(openxr_sdk)
if(MSVC AND TARGET openxr_loader)
    # The loader is linked into the packaged runtime. Remove compiler timestamps
    # from its object files so independent release trees produce the same EXE.
    target_compile_options(openxr_loader PRIVATE
        /Brepro /experimental:deterministic
        "/pathmap:${CMAKE_BINARY_DIR}=."
    )
endif()

FetchContent_Declare(
    minhook
    GIT_REPOSITORY https://github.com/TsudaKageyu/minhook.git
    GIT_TAG c3fcafdc10146beb5919319d0683e44e3c30d537
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(minhook)

add_library(A3VR SHARED
    src/d3d11_capture.cpp
    src/d3d11_capture.hpp
    src/dxgi_format_compat.hpp
    src/extension.cpp
    src/game_context.hpp
    src/pose.hpp
    src/shared_state.cpp
    src/shared_state.hpp
)

target_compile_definitions(A3VR PRIVATE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
    A3VR_VERSION="${PROJECT_VERSION}"
)

target_compile_options(A3VR PRIVATE /W4 /permissive- /EHsc /utf-8 /Brepro)
target_link_options(A3VR PRIVATE /Brepro)
target_link_libraries(A3VR PRIVATE minhook d3d11 dxgi)
set_target_properties(A3VR PROPERTIES
    OUTPUT_NAME "A3VRHybridCore_x64"
    PREFIX ""
)

add_executable(A3VRServer
    src/server_main.cpp
    src/controller_aim_output.cpp
    src/controller_aim_output.hpp
    src/absolute_weapon_pose.hpp
    src/controller_input_output.cpp
    src/controller_input_output.hpp
    src/freetrack_output.cpp
    src/freetrack_output.hpp
    src/dxgi_format_compat.hpp
    src/game_context.hpp
    src/openxr_tracker.cpp
    src/openxr_tracker.hpp
    src/pose.hpp
    src/shared_state.cpp
    src/shared_state.hpp
)
target_compile_definitions(A3VRServer PRIVATE
    WIN32_LEAN_AND_MEAN NOMINMAX XR_USE_PLATFORM_WIN32 XR_USE_GRAPHICS_API_D3D11
)
target_compile_options(A3VRServer PRIVATE
    /W4 /permissive- /EHsc /utf-8 /Brepro /experimental:deterministic
    "/pathmap:${CMAKE_BINARY_DIR}=."
)
target_link_options(A3VRServer PRIVATE /Brepro)
target_link_libraries(A3VRServer PRIVATE openxr_loader d3d11 dxgi user32)
set_target_properties(A3VRServer PROPERTIES OUTPUT_NAME "A3VRRuntime_v31")

add_executable(a3vr_math_tests
    tests/pose_tests.cpp
    src/absolute_weapon_pose.hpp
    src/controller_aim_output.cpp
    src/controller_aim_output.hpp
    src/controller_input_output.cpp
    src/controller_input_output.hpp
    src/pose.hpp
    src/freetrack_output.cpp
    src/freetrack_output.hpp
    src/game_context.hpp
    src/dxgi_format_compat.hpp
)
target_compile_options(a3vr_math_tests PRIVATE /W4 /permissive- /EHsc /utf-8 /UNDEBUG)
target_link_libraries(a3vr_math_tests PRIVATE user32)

add_executable(a3vr_extension_smoke tests/extension_smoke.cpp)
target_compile_definitions(a3vr_extension_smoke PRIVATE
    A3VR_EXPECTED_VERSION="${PROJECT_VERSION}"
)
target_compile_options(a3vr_extension_smoke PRIVATE /W4 /permissive- /EHsc /utf-8 /UNDEBUG)
target_link_libraries(a3vr_extension_smoke PRIVATE A3VR)

add_executable(a3vr_openxr_diagnostic tests/openxr_diagnostic.cpp)
target_compile_options(a3vr_openxr_diagnostic PRIVATE /W4 /permissive- /EHsc /utf-8)
target_link_libraries(a3vr_openxr_diagnostic PRIVATE A3VR)
set_target_properties(a3vr_openxr_diagnostic PROPERTIES OUTPUT_NAME "a3vr_openxr_probe")
enable_testing()
add_test(NAME a3vr_math_tests COMMAND a3vr_math_tests)
add_test(NAME a3vr_extension_smoke COMMAND a3vr_extension_smoke)

install(TARGETS A3VR A3VRServer RUNTIME DESTINATION "@A3VR_Hybrid")
install(DIRECTORY addons DESTINATION "@A3VR_Hybrid")
install(FILES
    a3vr-motion.ini
    mod.cpp
    README.md
    ROADMAP.md
    RELEASE_NOTES.md
    SECURITY.md
    LICENSE
    NOTICE
    THIRD_PARTY_LICENSES.md
    DESTINATION "@A3VR_Hybrid"
)
install(FILES a3vr-runtime.example.ini
    DESTINATION "@A3VR_Hybrid"
    RENAME "a3vr-runtime.ini"
)
install(FILES docs/OPENXR_COMPATIBILITY.md
    DESTINATION "@A3VR_Hybrid/docs"
)
