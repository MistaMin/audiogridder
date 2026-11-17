/*
 * Tests for the per-plugin oversampling. They use audio units that ship with macOS, so they need no test data.
 */

#ifndef _OVERSAMPLINGTEST_HPP_
#define _OVERSAMPLINGTEST_HPP_

#include <JuceHeader.h>
#include <atomic>
#include <thread>

#include "TestsHelper.hpp"
#include "ProcessorChain.hpp"
#include "Processor.hpp"

namespace e47 {

#if JUCE_MAC

class OversamplingTest : UnitTest {
  public:
    OversamplingTest() : UnitTest("Oversampling") {}

    const double sampleRate = 48000.0;
    const int blockSize = 512;
    LogTag testTag{"test"};

    struct Chain {
        std::unique_ptr<ProcessorChain> pc;
        std::shared_ptr<Processor> proc;
        TestsHelper::TestPlayHead phead;
        ~Chain() {
            if (nullptr != pc) {
                while (pc->getSize() > 0) {
                    pc->delProcessor(0);
                }
                pc->releaseResources();
            }
        }
    };

    // Loads a system audio unit into a new chain, id is "type,subtype,manufacturer".
    std::unique_ptr<Chain> load(const String& auId, int chIn, int chOut) {
        auto chain = std::make_unique<Chain>();
        chain->pc = std::make_unique<ProcessorChain>(&testTag, ProcessorChain::createBussesProperties(chIn, chOut, 0),
                                                 HandshakeRequest());
        chain->pc->updateChannels(chIn, chOut, 0);
        chain->pc->prepareToPlay(sampleRate, blockSize);
        OwnedArray<PluginDescription> types;
        runOnMsgThreadSync([&] {
            AudioUnitPluginFormat fmt;
            fmt.findAllTypesForFile(types, "AudioUnit:" + auId);
        });
        expect(!types.isEmpty(), "audio unit " + auId + " not found");
        if (types.isEmpty()) {
            return nullptr;
        }
        chain->proc = std::make_shared<Processor>(*chain->pc, Processor::createPluginID(*types[0]), sampleRate, blockSize);
        String err;
        bool loaded = chain->proc->load({}, {}, 0, err, types[0]);
        expect(loaded, "load of " + auId + " failed: " + err);
        if (!loaded) {
            return nullptr;
        }
        chain->pc->addProcessor(chain->proc);
        chain->pc->setPlayHead(&chain->phead);
        return chain;
    }

    // Plays one note at the given position of the first block and returns the sample at which sound starts.
    int noteOnset(int factor, int notePos) {
        auto chain = load("aumu,dls ,appl", 0, 2);
        if (nullptr == chain) {
            return -1;
        }
        chain->pc->setOversamplingFactor(0, factor);
        AudioBuffer<float> buf(2, blockSize);
        for (int block = 0; block < 8; block++) {
            MidiBuffer midi;
            if (block == 0) {
                midi.addEvent(MidiMessage::noteOn(1, 84, 1.0f), notePos);
            }
            buf.clear();
            chain->pc->processBlock(buf, midi);
            for (int s = 0; s < blockSize; s++) {
                if (std::abs(buf.getSample(0, s)) > 1.0e-3f) {
                    return block * blockSize + s;
                }
            }
        }
        return -1;
    }

    void runTest() override {
        beginTest("Change the factor while audio is processed");
        if (auto chain = load("aufx,dely,appl", 2, 2)) {
            int latencyOff = chain->pc->getLatencySamples();
            std::atomic_bool stop{false};
            std::thread audio([&] {
                AudioBuffer<float> buf(2 + chain->pc->getExtraChannels(), blockSize);
                MidiBuffer midi;
                while (!stop) {
                    setBufferSamples(buf, 0.5f);
                    chain->pc->processBlock(buf, midi);
                }
            });
            for (int round = 0; round < 10; round++) {
                for (int factor : {2, 4, 1, 4, 2, 1}) {
                    chain->pc->setOversamplingFactor(0, factor);
                    expect(chain->proc->getOversamplingFactor() == factor);
                }
            }
            stop = true;
            audio.join();

            beginTest("Latency is reported right after the change");
            chain->pc->setOversamplingFactor(0, 4);
            expect(chain->pc->getLatencySamples() > latencyOff, "chain latency " + String(chain->pc->getLatencySamples()));
            expect(chain->pc->getLatencySamples() == chain->proc->getLatencySamples());

            beginTest("Block larger than the announced block size");
            AudioBuffer<float> big(2 + chain->pc->getExtraChannels(), blockSize * 4);
            MidiBuffer midi;
            for (int i = 0; i < 4; i++) {
                setBufferSamples(big, 0.5f);
                chain->pc->processBlock(big, midi);
            }
            bool finite = true;
            for (int s = 0; s < big.getNumSamples(); s++) {
                finite = finite && std::isfinite(big.getSample(0, s));
            }
            expect(finite);
            expect(std::abs(big.getSample(0, big.getNumSamples() - 1)) > 0.1f, "no signal after the large blocks");
        }

        beginTest("MIDI positions with oversampling");
        for (int factor : {1, 2, 4}) {
            int early = noteOnset(factor, 32), late = noteOnset(factor, 432);
            logMessage("factor " + String(factor) + ": note at 32 sounds at " + String(early) + ", note at 432 at " +
                       String(late));
            expect(early >= 0 && late >= 0, "no sound from the instrument");
            // 400 samples between the notes must stay 400 samples in the output
            expect(std::abs((late - early) - 400) <= 16,
                   "factor " + String(factor) + ": onsets are " + String(late - early) + " samples apart");
        }
    }
};

static OversamplingTest oversamplingTest;

#endif

}  // namespace e47

#endif  // _OVERSAMPLINGTEST_HPP_
