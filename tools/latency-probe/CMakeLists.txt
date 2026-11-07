cmake_minimum_required(VERSION 3.22)
project(OpenGridderLatencyProbe LANGUAGES C CXX)

# Isolated DSP measurement: no FFmpeg, plugin SDKs, signing or GUI required.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_subdirectory(../../JUCE juce EXCLUDE_FROM_ALL)
add_executable(opengridder-latency-probe main.cpp)
target_compile_definitions(opengridder-latency-probe PRIVATE
    JUCE_WEB_BROWSER=0 JUCE_USE_CURL=0 JUCE_USE_FLAC=0 JUCE_USE_OGGVORBIS=0
    JUCE_STANDALONE_APPLICATION=1)
target_link_libraries(opengridder-latency-probe PRIVATE juce::juce_dsp)
