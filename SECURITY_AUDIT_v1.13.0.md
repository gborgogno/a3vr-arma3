# A3VR Hybrid 1.13.0 Security Audit

Audit date: 2026-08-13

## Scope

- All Git-tracked A3VR source, scripts, tests, and CI configuration.
- Pinned OpenXR SDK and MinHook dependency revisions.
- Release build outputs `A3VRHybridCore_x64.dll` and
  `A3VRRuntime_v30.exe`.
- The complete 11-file packaged mod under `standalone-mod/@A3VR_Hybrid`.

## Results

- No critical, high, or medium-severity finding was identified in A3VR-owned
  code.
- Microsoft Defender custom scan: no threats in the packaged mod.
- Microsoft Defender custom scan: no threats in the complete repository and
  build artifacts.
- MSVC Native Recommended Rules analysis: zero warnings and zero errors in
  A3VR-owned targets. Twelve warnings were emitted by the pinned OpenXR SDK's
  bundled JsonCpp implementation; none originate in A3VR source.
- Credential scan: no embedded API keys, access tokens, client secrets,
  passwords, or private keys.
- Git object verification completed successfully with `git fsck --full`.
- Both native binaries are x64, ASLR-enabled, high-entropy-ASLR-enabled, and
  NX-compatible.
- OpenXR SDK and MinHook are fetched at immutable Git commit hashes rather
  than floating branches or tags.

## Expected sensitive behavior

A3VR is a native VR bridge and therefore performs operations that generic
security tools may classify as sensitive:

- The runtime loads `A3VRHybridCore_x64.dll` into `arma3_x64.exe` so it can
  capture the game's D3D11 swapchain.
- The DLL hooks DXGI Present/ResizeBuffers with MinHook.
- The runtime uses Windows `SendInput` for controller-to-game input mapping.
- The DLL launches only the fixed `A3VRRuntime_v30.exe` filename located in
  its own directory. It does not execute a command received from SQF or from
  the network.

The reviewed code contains no network client, downloader, persistence through
the registry or services, telemetry upload, credential access, or arbitrary
shell-command execution.

## Remaining distribution notes

- The native binaries are not Authenticode-signed. SHA-256 provenance is
  recorded in `workshop/a3vr-hybrid-v1.13.0-sha256.json`; Authenticode signing
  is recommended before a future public release.
- The PBO is not multiplayer-key-signed. A private Workshop test does not
  require it, but a `.bikey`/`.bisign` release process is recommended before
  broad multiplayer distribution.
- Windows Defender reported real-time protection disabled on the audit host.
  The requested custom scans still completed successfully; this audit did not
  change Windows security settings.

## Package identity

The authoritative file-by-file SHA-256 and size manifest is:

`workshop/a3vr-hybrid-v1.13.0-sha256.json`
