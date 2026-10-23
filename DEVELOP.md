# Developer Guide

Help is very much welcome and so are pull requests!

## Building

Here is how you can build AudioGridder. Note that building the server is only
supported on macOS and Windows.

```
# Checkout the code
git clone --recurse-submodules https://github.com/MistaMin/audiogridder.git
cd audiogridder

# Checkout the dependencies
git clone https://github.com/apohl79/audiogridder-deps.git

# Configure and compile
python3 build.py conf --disable-signing
python3 build.py build
```

Or configure CMake directly, for example on Apple Silicon:

```
cmake -S . -B build-macos-arm64 -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DAG_MACOS_TARGET=11.1 \
  -DAG_DEPS_ROOT=<path>/audiogridder-deps/macos-11.1-arm64 \
  -DAG_ENABLE_CODE_SIGNING=OFF
ninja -C build-macos-arm64
```

Requirements: CMake 3.15+, a C++20 compiler, and on macOS Xcode 12.4 or later.
`AG_SDKS_ROOT` is optional. VST2 hosting and the VST2 plugin are only built
when a VST2 SDK exists at `$AG_SDKS_ROOT/vstsdk2.4`, AAX when
`AG_AAX_PLUGIN_ENABLED` is on and the AAX SDK exists.

### JUCE

The `JUCE` submodule is a patched JUCE fork
([MistaMin/JUCE](https://github.com/MistaMin/JUCE), branch
`audiogridder-9.0.4`). Its commit on top of the JUCE release tag carries the
AudioGridder changes: unix domain socket and IPv6 support in `StreamingSocket`
and the interprocess classes, extra launch arguments and separate read/ping
timeouts for `ChildProcessCoordinator`/`ChildProcessWorker`, and
`AudioProcessor::getAUChannelInfo()`.

To move to a newer JUCE release, create a new branch from the release tag,
cherry-pick that commit, resolve conflicts, and point the submodule at it.
Then regenerate the third-party licence notices:

```
package/update-third-party-licenses.sh
```

### Building with Visual Studio Code on Linux
- Install juce dependencies, build essentials along with g++
- Download and install VSCode
- Install Microsoft C/C++ extension pack and CMake tools along with ninja build
- Open AudioGridder folder and import. All configuration will be set automatically.
- Select build type, target and build

## Platforms

| Platform | Architecture | Status | Dependencies |
|---|---|---|---|
| macOS 11.1+ | universal (arm64 + x86_64) | released | `audiogridder-deps/macos-11.1-arm64` and `macos-11.1-x86_64` (combined with lipo) |
| Windows 10+ | x86_64 | released via GitHub Actions | `audiogridder-deps/windows-x86_64` |
| Linux | x86_64 | released via GitHub Actions | `audiogridder-deps/linux-x86_64` |
| Windows 10+ | ARM64 | source only, not released | build FFmpeg, libwebp and Boost for ARM64 (see below) |
| Linux | ARM64 | source only, not released | build FFmpeg, libwebp and Boost for ARM64 (see below) |

Each platform uses the same CMake project. Set `AG_DEPS_ROOT` to the folder that contains the
platform's `include` and `lib` folders, and `AG_SDKS_ROOT` to the folder with the optional SDKs.

### Building for Windows or Linux ARM64

These builds are not released, but the project can be built on those platforms:

1. Build FFmpeg (the libraries listed in `cmake/FindFFmpeg.cmake`), libwebp (with `webpmux`)
   and Boost headers for the target. The `audiogridder-deps` repository's `build.py` shows the
   configure options used for the other platforms.
2. Configure and build:

   ```
   cmake -S . -B build-arm64 -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo \
     -DAG_DEPS_ROOT=<path to the ARM64 dependencies> -DAG_ENABLE_CODE_SIGNING=OFF
   cmake --build build-arm64
   ```

3. The VST3, CLAP and LV2 plug-ins are built by default. AAX is optional and needs the AAX SDK
   (`-DAG_AAX_PLUGIN_ENABLED=ON -DAG_AAX_SDK=<path>`).

These steps are not tested on ARM64 hardware by the maintainers.

### AAX signing

AAX plug-ins must be signed by PACE. Run `wraptool sign` on each `.aaxplugin` bundle, with the
account, wrap configuration GUID and the Developer ID Application identity:

```
wraptool sign --verbose --account <PACE account> --wcguid <wrap config GUID> \
  --signid "Developer ID Application: <name> (<team>)" \
  --in "<bundle>.aaxplugin" --out "<signed bundle>.aaxplugin" --autoinstall on
wraptool verify --verbose --in "<signed bundle>.aaxplugin"
```

The account, GUID and identity are personal to the signing developer. Keep them out of the
repository. The release script expects the signed bundles in the folder named by `AG_AAX_SIGNED_DIR`.

The signing iLok must be synchronized in iLok License Manager and show as certified for digital
signing.

## Releases

Releases are published on the
[releases page](https://github.com/MistaMin/audiogridder/releases) of the fork.
A release consists of the macOS installers, the macOS permissions guide and a
complete source archive.

1. Set the version. This updates `Common/Source/Version.hpp` and
   `package/VERSION.num`:

   ```
   package/setversion.sh 1.3.0 marcosfork-1.3.0
   ```

2. Update `CHANGELOG.md`, and `README.md` where versions or file names are
   mentioned. Regenerate the macOS permissions guide, which takes the version
   from `package/VERSION.num` (requires `pip install reportlab`):

   ```
   python3 package/docs/make_macos_permissions_guide.py
   ```

3. If JUCE changed, regenerate the third-party licence notices with
   `package/update-third-party-licenses.sh`. Check `package/licenses/LICENSES.txt`.

4. Build (see above), then create the signed and notarized macOS installers:

   ```
   package/buildMacRelease.sh build-macos-arm64 <output dir>
   ```

   The script signs every bundle with the Developer ID Application certificate
   (hardened runtime, secure timestamp, `package/AudioGridderServer.entitlements`
   for the server), builds the server and plugin installers including the
   licences and the permissions guide, signs them with the Developer ID
   Installer certificate, and notarizes and staples them. Run it from your own
   Terminal, because `codesign` and `notarytool` may need to ask for keychain
   access. It expects a notary keychain profile, created once with:

   ```
   xcrun notarytool store-credentials AC_NOTARY --apple-id <apple id> --team-id <team id>
   ```

5. Commit, tag the release and push the branch and the tag. Push the JUCE fork
   branch first if the submodule changed:

   ```
   git tag -a v1.3.0 -m "AudioGridder 1.3.0"
   git push fork marcosfork-1.2.1 v1.3.0
   ```

6. Create the source archive. GitHub's automatic source downloads leave out the
   JUCE submodule, so this archive includes it:

   ```
   package/makeSourceArchive.sh <output dir>
   ```

7. Create the GitHub release for the tag and attach the installers, the
   permissions guide, the source archive and `SHA256SUMS.txt`.

## Coding conventions

Please follow the existing coding style (*m_* notation for class member
variables, cammel case for class, member and variable names, curly braces for
single statement control blocks, etc). Also before submitting a pull request,
make sure you are running the code formater.

```
python3 build.py format
```

Thanks for your contributions!
