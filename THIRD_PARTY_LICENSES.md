# Third-Party Licenses

This file lists third-party components used by the A3VR project and documents compliance with their licenses.

## Dependencies

### OpenXR SDK
- **Repository**: https://github.com/KhronosGroup/OpenXR-SDK
- **License**: Apache License 2.0
- **Version pinned in CMakeLists.txt**: Commit `00678df64b49ad878a8e882af933c28518cafd1c`
- **Distribution**: Fetched at build time via CMake FetchContent
- **Compliance**: Apache 2.0 is compatible with A3VR's Apache 2.0 license. Full license text included in `third_party/OPENXR_LICENSE.txt`
- **Attribution**: Required in distributed binaries/source

### MinHook
- **Repository**: https://github.com/TsudaKageyu/minhook
- **License**: BSD-3-Clause
- **Version pinned in CMakeLists.txt**: Commit `c3fcafdc10146beb5919319d0683e44e3c30d537`
- **Distribution**: Fetched at build time via CMake FetchContent; compiled into `A3VRHybridCore_x64.dll`
- **Compliance**: BSD-3-Clause is compatible with A3VR's Apache 2.0 license. Full license text included in `third_party/MINHOOK_LICENSE.txt`
- **Attribution**: Required in distributed binaries/source

### a3lib.py
- **Repository**: https://github.com/4d4a5852/a3lib.py
- **License**: MIT
- **Usage**: CI/CD packaging pipeline only; not distributed in runtime or release builds
- **Compliance**: MIT license is compatible with A3VR's Apache 2.0 license. Full license text included in `third_party/A3LIB_LICENSE.txt` for reference
- **Attribution**: Required if source is distributed; not required for binary releases

### OpenXR Runtimes (Runtime Dependency)
- **Examples**: Meta OpenXR, SteamVR, VDXR
- **License**: Varies by vendor/runtime
- **Distribution**: Not bundled with A3VR; end-users install from vendor
- **Compliance**: Each runtime is installed separately; no compliance action required by A3VR

## Distribution Compliance

### For Binary Releases
1. Include the `third_party/` directory with all license files
2. Include attribution notices in release documentation or README
3. Ensure `NOTICE` file references third-party components

### For Source Distributions
1. Include the `third_party/` directory
2. Retain copyright notices in source files
3. Include this file and the `LICENSE` file

### For Bundled Binaries
1. Retain license files in the distribution package (e.g., inside `@A3VR_Hybrid` mod directory)
2. Include a `THIRD_PARTY_LICENSES.md` copy in the package root or docs

## Adding New Dependencies

When adding a new dependency, follow these steps:

1. **Add to CMakeLists.txt** with a pinned commit SHA
2. **Document in this file** with:
   - Repository URL
   - License type and version
   - Pinned commit/version
   - Compatibility notes
3. **Add license file** to `third_party/` directory with format: `{LIBRARY}_LICENSE.txt`
4. **Update NOTICE** if the license type is GPLv2/v3 or includes distribution requirements

## Verification

All third-party licenses are compatible with Apache 2.0 and do not impose restrictions on binary distribution or closed-source use.

- Apache 2.0 ✅ Compatible with itself
- BSD-3-Clause ✅ Compatible with Apache 2.0
- MIT ✅ Compatible with Apache 2.0

**No GPL/LGPL dependencies are used.**

---

For questions or compliance review, refer to the original repository LICENSE file or contact the project maintainer.
