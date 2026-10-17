# Changelog

Changes in this fork ([MistaMin/audiogridder](https://github.com/MistaMin/audiogridder))
compared to upstream [apohl79/audiogridder](https://github.com/apohl79/audiogridder).

## 1.3.0 (marcosfork)

macOS installers for Apple Silicon. There is no Windows build of 1.3.0 yet.

- Built against JUCE 9.0.4. The JUCE submodule now points at the
  `audiogridder-9.0.4` branch of [MistaMin/JUCE](https://github.com/MistaMin/JUCE),
  which carries the AudioGridder JUCE patches (unix domain sockets, IPv6
  listeners, child process launch arguments and timeouts, AU channel
  capabilities) ported to JUCE 9. `StreamingSocket::isLocal()` now also
  recognises IPv6 interface addresses.
- Minimum systems are now macOS 11.1 and Windows 10 (1607). JUCE 9 does not
  support older systems.
- macOS window snapshots use JUCE's ScreenCaptureKit path on macOS 15 and later.
- VST2 hosting in the server is only enabled when a VST2 SDK is present.
- Build: macOS AppleDouble (`._*`) files are ignored when collecting sources.
- Distribution: the licence bundle now covers JUCE 9 and every third-party
  component JUCE compiles in (`package/licenses/third-party`, regenerated with
  `package/update-third-party-licenses.sh`).
- macOS packages are signed with a Developer ID, use the hardened runtime and
  are notarized (`package/buildMacRelease.sh`). The installers show the
  licences and install them, together with the new macOS permissions guide
  (PDF), to `/Library/Documentation/AudioGridder`.
- The server declares its local network use (needed on macOS 15 and later).
- Fix: the server could crash on startup on recent macOS when the splash
  window was released on a background thread.
- Documentation: README, developer guide and changelog describe the fork,
  installation from GitHub releases, building and releasing.

## 1.2.1 (marcosfork)

- Server: optional per-plugin 2x/4x oversampling. The plugin is re-prepared at
  the oversampled rate and block size, and the added latency is reported for
  delay compensation.
- Plugin: oversampling button (1x/2x/4x) next to the bypass button. The factor
  is saved in the plugin state (state version 7).
- Network: new `SetPluginOversampling` message (type 75).
- Fix: saving the server settings persists the configuration again (regression
  from upstream PR #1354).
- Build: VST2 and AAX are only enabled when their SDKs are present.
- Windows build fixes (MSVC includes, vcpkg library names, static FFmpeg/WebP
  system libraries, `boost-lockfree` instead of the full Boost package).
- Distribution licence bundle (`package/licenses`).
