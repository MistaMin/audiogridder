#pragma once

#include <cmath>

namespace e47 {

// Hosted processors report latency at the sample rate passed to prepareToPlay.
// Convert to the chain's base rate and round only after adding the filter delay.
// The host API reports integer samples; this does not add a fractional-delay filter.
inline int baseRateOversamplingLatency(int pluginSamples, int factor, double filterSamples) {
    const int rateFactor = factor == 2 || factor == 4 ? factor : 1;
    return static_cast<int>(std::lround(static_cast<double>(pluginSamples) / rateFactor + filterSamples));
}

}  // namespace e47
