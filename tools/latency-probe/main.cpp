#include <juce_dsp/juce_dsp.h>
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <vector>
#include "../../Common/Source/OversamplingLatency.hpp"

// Reproduce Processor::runWithOversampling's filter options and insert a known
// delay at the *oversampled* rate. Verify the measured base-rate group delay.
static void measure(int stages, bool linearPhase, int baseBlock, double sampleRate) {
    using OS = juce::dsp::Oversampling<double>;
    const int factor = 1 << stages;
    OS os(1, static_cast<size_t>(stages),
          linearPhase ? OS::filterHalfBandFIREquiripple : OS::filterHalfBandPolyphaseIIR,
          true, false);
    os.initProcessing(static_cast<size_t>(baseBlock));
    os.reset();

    const int pluginDelayHighRate = 256;
    std::vector<double> delay(pluginDelayHighRate, 0.0);
    size_t cursor = 0;
    std::vector<double> impulse(4096, 0.0);
    juce::AudioBuffer<double> buffer(1, baseBlock);
    for (size_t offset = 0; offset < impulse.size(); offset += baseBlock) {
        buffer.clear();
        if (offset == 0) buffer.setSample(0, 0, 1.0);
        juce::dsp::AudioBlock<double> block(buffer);
        auto up = os.processSamplesUp(block);
        auto* samples = up.getChannelPointer(0);
        for (size_t n = 0; n < up.getNumSamples(); ++n) {
            const auto input = samples[n];
            samples[n] = delay[cursor];
            delay[cursor] = input;
            cursor = (cursor + 1) % delay.size();
        }
        os.processSamplesDown(block);
        std::copy_n(buffer.getReadPointer(0), baseBlock, impulse.begin() + offset);
    }

    // DC group delay = first moment / DC gain of the round-trip impulse.
    // For minimum phase this is a low-frequency reference, not a constant
    // broadband delay; the impulse peak is reported separately.
    double dc = 0.0, moment = 0.0;
    size_t peak = 0;
    for (size_t n = 0; n < impulse.size(); ++n) {
        dc += impulse[n];
        moment += static_cast<double>(n) * impulse[n];
        if (std::abs(impulse[n]) > std::abs(impulse[peak])) peak = n;
    }
    const double measuredDelay = moment / dc;
    const double expectedDelay = os.getLatencyInSamples() +
                                 static_cast<double>(pluginDelayHighRate) / factor;
    const double tolerance = linearPhase ? 1.0e-6 : 0.05;
    // Equiripple FIR coefficients have small passband ripple, including at DC.
    if (!std::isfinite(measuredDelay) || std::abs(dc - 1.0) > 0.001 ||
        std::abs(measuredDelay - expectedDelay) > tolerance) {
        std::cerr << "factor=" << factor << " linear=" << linearPhase << " dc=" << dc
                  << " delay=" << measuredDelay << " expected=" << expectedDelay << std::endl;
        throw std::runtime_error("impulse gain/group-delay verification failed");
    }

    const auto previousPdc = pluginDelayHighRate + std::lround(os.getLatencyInSamples());
    const auto baseRatePdc = std::lround(expectedDelay);
    const auto processorPdc = e47::baseRateOversamplingLatency(pluginDelayHighRate, factor, os.getLatencyInSamples());
    if (processorPdc != baseRatePdc)
        throw std::runtime_error("Processor PDC disagrees with measured rounded delay");
    std::cout << "{\"factor\":" << factor
              << ",\"filter\":\"" << (linearPhase ? "linear_phase_fir" : "minimum_phase_iir_reference")
              << "\",\"sample_rate\":" << sampleRate << ",\"block_size\":" << baseBlock
              << ",\"filter_delay_base_samples\":" << os.getLatencyInSamples()
              << ",\"filter_delay_ms\":" << os.getLatencyInSamples() * 1000.0 / sampleRate
              << ",\"mock_plugin_delay_high_rate_samples\":" << pluginDelayHighRate
              << ",\"measured_dc_delay_base_samples\":" << measuredDelay
              << ",\"impulse_peak_base_sample\":" << peak
              << ",\"previous_processor_pdc_samples\":" << previousPdc
              << ",\"processor_pdc_samples\":" << processorPdc
              << ",\"rounded_base_rate_pdc_samples\":" << baseRatePdc << "}" << std::endl;
}

int main() {
    std::cout << std::setprecision(12);
    try {
        // Exercise non-divisible plugin delays and fractional FIR latency: the
        // 258/4 + 59.5 case catches rounding the filter before summing.
        if (e47::baseRateOversamplingLatency(258, 4, 59.5) != 124 ||
            e47::baseRateOversamplingLatency(257, 2, 49.0) != 178 ||
            e47::baseRateOversamplingLatency(256, 1, 0.0) != 256 ||
            e47::baseRateOversamplingLatency(0, 4, 59.5) != 60)
            throw std::runtime_error("latency unit/rounding regression");
        for (const auto rate : {48000.0, 96000.0})
            for (const auto block : {32, 64, 128})
                for (const auto stages : {1, 2})
                    for (const auto fir : {true, false})
                        measure(stages, fir, block, rate);
    } catch (const std::exception& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
}
