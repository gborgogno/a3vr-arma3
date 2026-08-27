# Security policy

## Supported version

Security fixes target the latest GitHub release. Older alpha builds and local
test packages are not supported.

## Reporting a vulnerability

Do not open a public issue containing an exploit, credential, private log, or
other sensitive material. Use GitHub's private vulnerability reporting for
`gborgogno/a3vr-arma3` when available. Otherwise open a minimal issue asking the
maintainer for a private contact channel without publishing the sensitive data.

Include the affected release, Windows version, OpenXR runtime, reproduction
steps, impact, and the SHA-256 of the package tested. Remove account names,
local paths, server addresses, and private mod lists from logs.

## Expected native behavior

A3VR is a local native bridge. Its normal operation includes behavior that
endpoint security software may flag:

- Arma normally loads `A3VRHybridCore_x64.dll` through the extension interface.
  When the runtime starts first, it can preload that fixed DLL into a process
  whose executable name was verified as `arma3_x64.exe`; this uses the standard
  `WriteProcessMemory`/`CreateRemoteThread` + `LoadLibraryW` sequence.
- The extension hooks the local DXGI/D3D11 presentation path with MinHook to
  capture Arma's backbuffer.
- `A3VRRuntime_v31.exe` owns the OpenXR session and publishes FreeTrack data.
- The runtime exchanges pose/context data through local named shared memory,
  events, and mutexes.
- Controller bindings use the Windows `SendInput` API for local keyboard/mouse
  actions where Arma exposes no direct addon action.
- The extension may start only the fixed `A3VRRuntime_v31.exe` file beside the
  installed DLL. Runtime and DLL paths are constructed locally, not received
  from SQF or a network source.

The reviewed design has no telemetry, account login, updater, remote command
channel, persistence service, registry autorun, credential reader, or gameplay
network client. The optional launcher edits local Arma profile/configuration
files, creates backups, starts the local runtime, and opens the official Arma 3
Launcher. Administrator rights are not required.

## Distribution safety

- Download only from the repository's GitHub Releases page.
- Verify the release ZIP against its adjacent `.sha256` file.
- Do not use A3VR with BattlEye or on protected multiplayer servers.
- Release binaries are not Authenticode-signed and the PBO is not signed with a
  multiplayer key.
- OpenXR SDK, MinHook, the PBO packer, and GitHub Actions are pinned to immutable
  upstream object IDs in source/CI.
- Build trees, credentials, user profiles, videos, runtime overrides, and local
  test installations are excluded from release packaging.

Release-specific scan evidence is recorded in the corresponding
`SECURITY_AUDIT_*.md` file and in the GitHub Actions run for the tag. Static and
malware scans reduce risk but do not prove absence of vulnerabilities.
