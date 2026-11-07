# Source-matched oversampling latency probe

Build from the repository root, after `git submodule update --init JUCE`:

```sh
cmake -S tools/latency-probe -B build-latency-probe -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-latency-probe
build-latency-probe/opengridder-latency-probe > build-latency-probe/results.jsonl
```

This probe uses the pinned JUCE revision and the same maximum-quality,
non-integer-latency filter settings as `Server/Source/Processor.cpp`. It measures
2x and 4x at 32/64/128 frames and 48/96 kHz. It verifies unity DC gain and DC
group delay of an impulse through the oversampler with a known 256-sample
delay inside the oversampled callback. DC gain tolerance is 0.1%, allowing
equiripple passband ripple. Any verification failure returns nonzero.

The linear-phase FIR is the current production choice. The minimum-phase IIR
is a comparison only; it is **not** a minimum-phase FIR implementation and has
frequency-dependent delay. No production filter selection is changed.

The previous Processor added hosted-plugin latency without converting it from
the oversampled rate to the base rate. The output compares that calculation
with the corrected production helper, rounded once at the end. Fractional delay still
requires an explicit compensation policy before claiming exact integer PDC.

These are deterministic DSP measurements, not network latency, CPU benchmarks,
DAW compatibility tests, or proof of alias rejection. The server round trip,
buffering, host routing, and real hosted-plugin delay remain additional costs.
