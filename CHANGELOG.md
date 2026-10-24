# Changelog

Changes in this fork ([MistaMin/audiogridder](https://github.com/MistaMin/audiogridder))
compared to upstream [apohl79/audiogridder](https://github.com/apohl79/audiogridder).

## 1.3.3 (marcosfork)

- Fix: the MIDI AudioUnit failed Apple's `auval` validation ("Default Format of unit does not match
  reported Channel handling capabilities"), because JUCE 9 reported MIDI effects as having no audio
  inputs while AudioGridder's MIDI plug-in has a 2 channel input bus. This affected 1.3.0 to 1.3.2.
  The JUCE fork now only uses that shortcut for MIDI effects without an audio input bus. The
  effect, instrument and MIDI AudioUnits all pass `auval`.
- Licences: added the Avid trademark notice for AAX and Pro Tools, and the AAX SDK licence text
  (the SDK itself is not distributed).
- Source archive: includes every submodule, recursively.
- All binaries, installers and the AAX plug-ins are rebuilt and signed as 1.3.3. Behaviour is
  otherwise the same as 1.3.2.

## 1.3.2 (marcosfork)

- Fix: the Windows CLAP plug-ins were built, but into a folder that was not collected. They are
  now built into `lib/CLAP` and included in the Windows preview.
- Fix: on Linux the VST3 binary was written loose into `lib/` instead of into a `.vst3` bundle.
  It is now built into the bundle folder JUCE uses, so hosts can find it.
- All macOS binaries, installers and the AAX plug-ins are rebuilt and signed as 1.3.2. Behaviour
  is otherwise the same as 1.3.1.
- The 1.3.1 release notes said the Windows build had no CLAP. That was wrong. The files were built
  but not packaged.

## 1.3.1 (marcosfork)

- New plug-in formats: CLAP (built with clap-juce-extensions, MIT) and LV2, in
  addition to AudioUnit, VST3 and AAX. Each format has effect, instrument and MIDI
  plug-ins.
- AAX plug-ins are signed through PACE (wrap configuration for the AudioGridder product).
- macOS binaries are universal (Apple Silicon and Intel), built against macOS 11.1. The
  x86_64 FFmpeg and libwebp dependencies are cross-compiled and were run under Rosetta to test.
- Preview builds for Windows x64 (server, tray, VST3, LV2) and Linux x86_64 (server, tray,
  CLAP, LV2) from GitHub Actions. They are untested, and the Windows files are unsigned.
  (1.3.2 completes these previews, see above.) Windows ARM64 and Linux ARM64
  are not released, but can be built from source (see DEVELOP.md).
- Fix: the server could crash at startup on recent macOS when the splash window was
  released on a background thread.
- Fix: the installed applications were unreadable for other users, because the
  restrictive permissions of the build folder were copied into the installer. The
  release script now sets safe permissions before packaging.
- Licences: the binaries are freeware, provided without warranty (package/licenses/FREEWARE.txt).
  The notices for CLAP, clap-juce-extensions and LV2 are added.
- Documentation: README and developer guide describe the new formats and the release process.

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
