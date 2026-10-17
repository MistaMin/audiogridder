# AudioGridder

AudioGridder is a network bridge for audio and MIDI that allows for offloading
the DSP processing of audio plugins to remote computers running macOS or
Windows. This can come in handy when mixing complex projects or running CPU
intensive instruments for instance.  AudioGridder comes with a plugin and a
server and supports VST2, VST3, AudioUnit and LV2 plugin formats. Plugins can
be hosted and accessed across the network: simply run the AudioGridder server
on a remote machine and connect your DAW using the AudioGridder plugin. This
allows you to add remote insert chains or instruments into your DAW's signal
paths. The DSP code of the loaded remote plugins will be executed on the remote
machine and the remote plugin UI's will be streamed over the wire. With
AudioGridder you get an experience very close to hosting the plugins directly
in your DAW but not using your local CPU.

<p align="left">
<img src="https://audiogridder.com/wp-content/uploads/2021/03/diagram-gray.png" width="500" />
</p>

# About this fork

This is a fork of [apohl79/audiogridder](https://github.com/apohl79/audiogridder)
by Andreas Pohl, maintained at
[MistaMin/audiogridder](https://github.com/MistaMin/audiogridder). The current
version is **1.3.0**. Compared to upstream 1.2 it adds:

- per-plugin 2x/4x oversampling on the server,
- a build against JUCE 9, using the patched JUCE fork at
  [MistaMin/JUCE](https://github.com/MistaMin/JUCE) (branch `audiogridder-9.0.4`),
- signed and notarized macOS installers,
- a guide for the macOS Accessibility, Screen Recording and local network
  permissions,
- a number of fixes.

All changes are listed in [CHANGELOG.md](CHANGELOG.md). Information on the
upstream project is at [https://audiogridder.com](https://audiogridder.com).
Please don't report problems with fork builds to the upstream project.

# Installation

Download the installers from the
[releases page](https://github.com/MistaMin/audiogridder/releases) of this fork.

## macOS

AudioGridder 1.3.0 is available for Macs with Apple Silicon running macOS 11.1
or later. Both installers are signed and notarized by Apple.

- `AudioGridderServer_1.3.0_macOS-arm64.pkg`: install on the computer that runs
  the plugins. Installs `AudioGridderServer.app` into Applications.
- `AudioGridderPlugin_1.3.0_macOS-arm64.pkg`: install on the computer that runs
  your DAW. Installs the AudioUnit and VST3 plugins (effect, instrument and
  MIDI) and `AudioGridderPluginTray.app`.

On the server Mac, AudioGridder Server needs the **Accessibility** and **Screen
Recording** permissions, and on macOS 15 and later both computers need **local
network** access. The
[macOS permissions guide](package/docs/AudioGridder-macOS-Permissions.pdf)
explains each step. It is also attached to every release, and the installers
put it in `/Library/Documentation/AudioGridder`, together with the licences.

The Homebrew packages `audiogridder-plugin` and `audiogridder-server` install
the upstream version, not this fork.

## Windows

There is no Windows build of 1.3.0 yet. The fork's Windows build of 1.2.1 is on
the [releases page](https://github.com/MistaMin/audiogridder/releases/tag/win-only-1.2.1).

## Linux

The plugin can be built for Linux from source, see [DEVELOP.md](DEVELOP.md).

# Features

- VST2 / VST3 / AAX / AudioUnit (macOS only) plugin
- Hosting of AudioUnit (macOS only), VST3, LV2 and VST2 plugins
- Effect & Instrument plugins
- Latency compensation
- 32/64 bit float processing
- Per-plugin 2x/4x oversampling
- Audio over network
- Midi over network
- Unlimited remote effect plugin chains
- Streaming of plugin UIs
- Local control of remote plugin UI's
- Generic Plugin Parameter Editor
- Automation

The released macOS installers contain the AudioUnit and VST3 plugins. VST2 and
AAX need their SDKs and are only built when those are available.

# Compatibility

- Server: macOS 11.1+, Windows 10 (1607)+
- Plugin: macOS 11.1+, Windows 10 (1607)+, Linux
- AudioGridder is 64bit only
- Released macOS installers: Apple Silicon (arm64)

Since 1.3.0 the fork uses JUCE 9, which no longer supports macOS older than
10.11 or Windows 7/8. Use an upstream 1.2 release for older systems.

# Licence

AudioGridder is licensed under the MIT License, see [COPYING](COPYING). The
binary releases include third-party components (JUCE, FFmpeg, libwebp, Boost
and the components JUCE compiles in). Their notices are in
[package/licenses](package/licenses). JUCE is used under a commercial JUCE 9
licence held by the distributor of the binaries.

# Donations

AudioGridder was created by Andreas Pohl and is free. If you use it, please
consider supporting the original project:

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MF9TGYY8P8GG4)
[![donorbox](https://d1iczxrky3cnb2.cloudfront.net/button-small-blue.png)](https://donorbox.org/audiogridder?default_interval=o)

# Contributing

Pull requests are welcome! Please follow the
[development guide](DEVELOP.md) if you'd like to contribute to the project and
to get started.
