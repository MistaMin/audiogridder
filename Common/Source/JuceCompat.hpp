/*
 * Copyright (c) 2026 AudioGridder contributors
 *
 * Small shims that let the same sources build with JUCE 9 (modern builds) and with JUCE 7.0.5
 * (legacy builds for macOS 10.7+ and Windows 7+, AG_LEGACY). Keep every JUCE version difference here.
 */

#pragma once

#include <JuceHeader.h>

namespace e47 {

#ifdef AG_LEGACY

#define AG_JUCE_CONST

#if JUCE_MODULE_AVAILABLE_juce_audio_processors
inline void agAddDefaultFormats(juce::AudioPluginFormatManager& mgr) { mgr.addDefaultFormats(); }
#endif

inline juce::Thread::RealtimeOptions agRealtimeOptions(double maxProcessingTimeMs) {
    juce::Thread::RealtimeOptions opts;
    opts.workDurationMs = (juce::uint32)maxProcessingTimeMs;
    return opts;
}

#if JUCE_MODULE_AVAILABLE_juce_audio_processors
inline juce::String agTrackName(const juce::AudioProcessor::TrackProperties& tp) { return tp.name; }
inline juce::uint32 agTrackColourARGB(const juce::AudioProcessor::TrackProperties& tp) { return tp.colour.getARGB(); }
#endif

inline int agStringWidth(const juce::Font& font, const juce::String& text) { return font.getStringWidth(text); }

#else

#define AG_JUCE_CONST const

#if JUCE_MODULE_AVAILABLE_juce_audio_processors
inline void agAddDefaultFormats(juce::AudioPluginFormatManager& mgr) { juce::addDefaultFormatsToManager(mgr); }
#endif

inline juce::Thread::RealtimeOptions agRealtimeOptions(double maxProcessingTimeMs) {
    return juce::Thread::RealtimeOptions().withMaximumProcessingTimeMs(maxProcessingTimeMs);
}

#if JUCE_MODULE_AVAILABLE_juce_audio_processors
inline juce::String agTrackName(const juce::AudioProcessor::TrackProperties& tp) {
    return tp.name.value_or(juce::String());
}
inline juce::uint32 agTrackColourARGB(const juce::AudioProcessor::TrackProperties& tp) {
    return tp.colourARGB.value_or(0);
}
#endif

inline int agStringWidth(const juce::Font& font, const juce::String& text) {
    return juce::GlyphArrangement::getStringWidthInt(font, text);
}

#endif

}  // namespace e47
