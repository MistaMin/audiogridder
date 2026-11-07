# OpenGridder latency source audit

2026-10-24. AudioGridder fork commit `36786810d346c12fe6600457d77e77ece92d0532`,
pinned JUCE commit `a480a36d4ece2dc8fdaae65b6318995d0858afe1`.

## Source findings

The C++ AudioGridder fork is a stronger candidate for the first production
client/server milestone than the Rust prototype: actual host wrappers, plugin
hosting, buffering, and sandbox infrastructure already exist. This is an
engineering recommendation, not certification of its legacy support.

- `Plugin/Source/AudioStreamer.hpp` pre-fills the read queue with
  `NUM_OF_BUFFERS` silent blocks. Positive buffer counts add that many server
  block durations. At 48 kHz, one 64-frame block adds 1.333 ms.
- `Plugin/Source/Client.hpp::getLatencySamples` adds server latency,
  `NUM_OF_BUFFERS * m_samplesPerBlock`, and manual compensation.
- Zero added buffers still performs a send/receive round trip. The live-mode
  path waits for its network thread. Buffered reads may also wait on a condition
  variable when the queue empties. Queue use alone does not make this callback
  bounded or wait-free.
- `m_readTimeoutMs` uses whole milliseconds calculated as block duration minus
  one millisecond. At 64 frames / 48 kHz it truncates to zero; smaller blocks
  also lose meaningful sub-millisecond deadline resolution. Replacing this
  with a larger arbitrary timeout would not establish safe callback deadlines.
- The pinned JUCE socket code already requests `TCP_NODELAY` for TCP sockets.
  Simply adding that flag is not a new transport optimization.
- `Server/Source/Processor.cpp` hard-codes linear-phase FIR for oversampling.
  `runWithOversampling` locks a mutex and lazily builds stages on the processing
  thread. Filter design/allocation needs to move into controlled preparation.
- Hosted plugins are prepared at `base rate * factor`. Their reported latency
  must be divided by that factor before adding the filter delay at base rate.
  The original code omitted that conversion in both latency paths.

## Measurements and first correction

The isolated probe passed 24 configurations: 2x/4x, FIR/IIR reference,
32/64/128-frame blocks, and 48/96 kHz. Each test sends an impulse through a
known 256-sample delay at the oversampled rate. It checks DC gain within 0.1%
(allowing FIR passband ripple), DC group delay, and production PDC rounding.

| Filter | Factor | Filter-only delay, base samples | Filter-only delay at 48 kHz |
| --- | --- | --- | --- |
| Linear-phase FIR, existing | 2x | 49 | 1.0208 ms |
| Linear-phase FIR, existing | 4x | 59.5 | 1.2396 ms |
| Minimum-phase IIR, comparison only | 2x | 3.13732 at low frequency | 0.0654 ms |
| Minimum-phase IIR, comparison only | 4x | 4.43267 at low frequency | 0.0923 ms |

The PDC correction divides plugin delay by the oversampling factor and retains
fractional filter delay until final integer rounding. With a 256-sample plugin
delay at 2x, the previous calculation reported 305 samples; the impulse arrives
at 177, matching the corrected value. At 4x the measured delay is 123.5 samples,
rounded to 124, versus 316 previously reported. Changing reported PDC corrects
alignment; it does not make DSP or network processing execute faster.

Validation performed: the corrected `Processor.cpp` translation unit compiled
with the repository's server configuration, and all 24 probe configurations
plus integer/fractional rounding regression cases passed. This is not a full
server link or DAW integration test.

The host API accepts integer samples. A fractional delay policy is still
required before claiming sample-exact broadband alignment for fractional
linear-phase totals. A minimum-phase filter has frequency-dependent group
delay; integer PDC cannot undo its phase response.

## Oversampling modes to implement

Preserve existing session sound by defaulting old sessions to their existing
linear-phase FIR. Proposed per-plugin options are Off, Linear-phase FIR, and
Minimum-phase FIR, with 2x/4x factors. Minimum-phase IIR can be a separately
named optional mode if desired; it must not be labelled as FIR.

Minimum-phase FIR requires a separate kernel design and validation of magnitude
response, alias rejection under nonlinear processing, impulse energy/delay,
CPU cost, f32/f64, and block partition independence. The current half-band
linear-phase symmetry/delay shortcut cannot simply be reused for it. Coefficients
and state must be prepared outside processing, and factor/phase changes need
controlled state replacement, persistence, protocol capability negotiation,
and host latency notification. Test MIDI event times at the oversampled rate
as part of that work; audio-rate conversion alone does not establish MIDI timing.

## Transport direction

Minimize fixed buffering while maintaining a callback that returns on time.
Use preallocated audio slots, explicit block sequence numbers, a dedicated
transport worker, stale-result rejection, and deterministic underrun handling.
Measure the lowest reliable queue depth under load. Avoid an unbounded wait
marketed as zero latency. Total delay still includes server round trip, host
routing and the hosted processor's own delay.

The legacy SDKs are available per the user. A working TDM system is unconfirmed.
TDM and RTAS delivery remain separate from this DSP probe. No Pro Tools host,
network round trip, third-party plugin crash test, or legacy OS test has been
qualified by these measurements.
