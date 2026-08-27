# A3VR Hybrid 1.0.0 security audit

Audit date: 2026-08-27

## Scope

- The Git history reachable from the release branch.
- Every tracked/new source, script, test, workflow, and document selected for
  the 1.0.0 commit.
- Pinned OpenXR SDK, MinHook, and PBO-packer references.
- Release binaries, PBO, scripts, documents, ZIP, and SHA-256 sidecar generated
  locally from the release candidate.

Excluded development trees, videos, user profiles, previous builds, optics
experiments, and recovery worktrees were not release inputs.

## Results

- Gitleaks 8.30.1 scanned 33 reachable commits: zero findings.
- Gitleaks scanned the exact release-source selection: zero findings.
- Gitleaks scanned the expanded release package: zero findings.
- A broad workspace scan reported three test-vector matches inside excluded
  tooling/old-worktree files (the Gitleaks README and a3lib's own test key).
  None is tracked by this release or present in the package.
- Microsoft Defender real-time protection was enabled with signature
  `1.457.362.0`. Custom scans of the release-source selection and expanded
  package produced zero new detections.
- MSVC Native Recommended Rules initially reported C6262 in
  `src/server_main.cpp`: a 64 KiB process-path buffer on the stack. The buffer
  was moved to heap-backed storage and the analysis was repeated; A3VR-owned
  targets then produced zero defects.
- The pinned OpenXR Loader sources produced 12 C26495/C26819 analysis warnings
  in bundled JsonCpp/logger code. They are upstream warnings, not A3VR-owned
  findings. MinHook produced no analysis defects.
- GitHub reported zero open Dependabot alerts for the repository.
- The OpenXR SDK, MinHook, and a3lib repositories listed zero published GitHub
  security advisories at audit time. Code-scanning and GitHub secret-scanning
  alert APIs were unavailable for this repository; they are not reported as
  zero.
- `git fsck --full` returned successfully. Unreachable objects from the local
  recovery stash/history were reported as dangling and are not release inputs.
- The ordinary Release build completed and both CTest tests passed (2/2).
- A second clean build downloaded the pinned dependencies into an independent
  tree and also passed 2/2. With deterministic compiler/linker metadata enabled,
  both trees produced byte-identical packaged DLL and runtime binaries.
- Actionlint 1.7.12 validated the GitHub Actions workflow with zero findings;
  its downloaded archive matched the publisher's checksum. Every PowerShell
  script parsed with zero syntax errors under Windows PowerShell tooling.
- The packaged extension smoke test passed against the DLL extracted from the
  final ZIP. All ten registered SQF function files were present in the PBO and
  retired hand-debug functions were absent.

## Package identity

- File: `A3VR-Hybrid-v1.0.0.zip`
- Size: `300932` bytes
- Entries: `16`, under one `@A3VR_Hybrid` root
- SHA-256:
  `4ad748d3d9ca76ed58efa61385ed9e2a93015147b9ae043e355328cab09a99ef`
- Sidecar hash verification: passed
- Forbidden build/profile/video/debug entries: none

Packaged native files:

| File | SHA-256 |
| --- | --- |
| `A3VRHybridCore_x64.dll` | `7f88ac9ac7c49c56fd8791ebd33141f7ba49c75c1e063c3ab4486904eb096238` |
| `A3VRRuntime_v31.exe` | `a7046e2a37f9f32f31ac20620ad40b3a4705bbd662a49797d7e8c1618f256fd1` |

Both binaries are x64 and have high-entropy ASLR, dynamic-base ASLR, and NX
compatibility enabled. Neither binary is Authenticode-signed. The PBO is also
not multiplayer-key-signed.

## Reviewed sensitive behavior

The release intentionally contains native behavior that generic security tools
may flag:

- DLL preloading into a process verified by executable name as `arma3_x64.exe`
  through `WriteProcessMemory`, `CreateRemoteThread`, and `LoadLibraryW`.
- DXGI/D3D11 Present and ResizeBuffers hooks through MinHook.
- Local `SendInput` calls for controller-to-Arma keyboard/mouse bindings.
- Local shared memory, named events/mutexes, FreeTrack output, and an OpenXR
  session.
- Launch of the fixed `A3VRRuntime_v31.exe` beside the installed extension.

The source inventory found no HTTP client, socket client, telemetry, updater,
registry/service persistence, credential reader, remote command channel, or
arbitrary shell-command execution in the runtime/addon.

## Reproducibility and supply chain

- OpenXR SDK tag object:
  `00678df64b49ad878a8e882af933c28518cafd1c`
  (`release-1.1.62`, peeled commit
  `57af7fc61f9f2d492580cb28aab6d0ea59d8d417`).
- MinHook commit: `c3fcafdc10146beb5919319d0683e44e3c30d537`.
- a3lib.py commit: `0d89b71a0b8453aba02ffd43edb6a6ee4e78b335`.
- GitHub Actions are pinned to immutable commit hashes.
- The release workflow builds/tests before packaging, separates read-only build
  permissions from the write-enabled publication job, validates the tag against
  `CMakeLists.txt`, and publishes ZIP plus SHA-256 from the tested artifact.

## Audit limits

This audit is not a penetration test, a formal proof, or an in-headset gameplay
test. CTest does not validate SQF semantics, stereo comfort, campaign/UI timing,
or every weapon/controller/OpenXR runtime. Those limitations remain documented
in `README.md`. Absence of scanner findings does not prove absence of defects.
