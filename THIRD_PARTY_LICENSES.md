# Third-Party Licenses

This file lists third-party components used by the project and how to comply
with their licenses. It is not a substitute for including the actual license
files from each dependency — copy each dependency's license into
`third_party/` or add the full text here when distributing.

Known third-party components referenced in this repository:

- OpenXR runtimes (e.g. Meta OpenXR, SteamVR/OpenXR): runtime licenses vary by
  vendor. The runtime is not distributed in this repo; users must install the
  runtime from the vendor and follow their license terms.
- MinHook (commonly used hooking library) — check the MinHook repository for
  the license (often BSD/MIT-style). Include the exact license text if you
  redistribute MinHook.
- 4d4a5852/a3lib.py — referenced by the CI packaging step. See the upstream
  repository for the license and include a copy if distributing.

Recommended actions for maintainers:

1. Create a `third_party/` directory and add each dependency's license file
   (e.g. `third_party/MINHOOK_LICENSE.txt`).
2. For bundled binaries or source from third parties, include attribution and
   the full license text in the distribution package.
3. When adding a new dependency, update this file with the dependency name,
   version and a short note about the required compliance (attribution, copy
   of license file, etc.).

Example entry to add when you vendor a library:

```
Name: MinHook
Version: 1.3.3
License: BSD-3-Clause
Notes: Include the MinHook LICENSE file in third_party/ and retain copyright
       notices in modified files.
```

If you need help auditing a particular dependency, tell me which one and I
can look up its license and add the appropriate notes and files here.
