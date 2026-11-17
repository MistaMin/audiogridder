/*
 * Tests for the network message layer: values from the wire must never be trusted over the size of the buffer.
 */

#ifndef _MESSAGETEST_HPP_
#define _MESSAGETEST_HPP_

#include <JuceHeader.h>

#include "TestsHelper.hpp"
#include "Message.hpp"
#include "Metrics.hpp"
#include "Utils.hpp"

namespace e47 {

class MessageTest : UnitTest {
  public:
    MessageTest() : UnitTest("Message") {}

    StreamingSocket listener, clnt;
    std::unique_ptr<StreamingSocket> srv;

    bool connect() {
        for (int port = 56990; port < 57000; port++) {
            if (listener.createListener(port, "127.0.0.1")) {
                if (clnt.connect("127.0.0.1", port, 2000)) {
                    srv.reset(listener.waitForNextConnection());
                }
                break;
            }
        }
        return nullptr != srv;
    }

    // Sends a message header followed by a string/binary style body: a length field and some bytes.
    void sendRaw(int type, int size, int lenField = 0, const char* bytes = nullptr, int numBytes = 0) {
        int hdr[2] = {type, size};
        clnt.write(hdr, sizeof(hdr));
        if (size > 0) {
            clnt.write(&lenField, sizeof(lenField));
            if (numBytes > 0) {
                clnt.write(bytes, numBytes);
            }
        }
    }

    void runTest() override {
        LogTag tag("test");
        MessageFactory factory(&tag);
        MessageHelper::Error e;

        beginTest("Connect");
        expect(connect(), "failed to create a local socket pair");
        if (nullptr == srv) {
            return;
        }

        beginTest("Message without a body");
        sendRaw(DelPlugin::Type, 0);
        auto msg = factory.getNextMessage(srv.get(), &e);
        expect(nullptr != msg, "read failed: " + e.toString());
        if (nullptr != msg) {
            expect(pPLD(Message<Any>::convert<DelPlugin>(msg)).getNumber() == 0);
        }

        beginTest("Negative size");
        sendRaw(Clipboard::Type, -5);
        msg = factory.getNextMessage(srv.get(), &e);
        expect(nullptr == msg && e.code == MessageHelper::E_DATA, "a negative size has to be rejected");

        beginTest("String length larger than the body");
        sendRaw(Clipboard::Type, 4 + 3, 1000, "abc", 3);
        msg = factory.getNextMessage(srv.get(), &e);
        expect(nullptr != msg, "read failed: " + e.toString());
        if (nullptr != msg) {
            expect(pPLD(Message<Any>::convert<Clipboard>(msg)).getString() == "abc");
        }

        beginTest("Key count larger than the body");
        uint16_t key = 7;
        sendRaw(Key::Type, 4 + 2, 1 << 20, reinterpret_cast<const char*>(&key), 2);
        msg = factory.getNextMessage(srv.get(), &e);
        expect(nullptr != msg, "read failed: " + e.toString());
        if (nullptr != msg) {
            expect(pPLD(Message<Any>::convert<Key>(msg)).getKeyCount() == 1);
        }

        beginTest("Json length larger than the body");
        sendRaw(AddPlugin::Type, 4 + 2, 5000, "{}", 2);
        msg = factory.getNextMessage(srv.get(), &e);
        expect(nullptr != msg, "read failed: " + e.toString());
        if (nullptr != msg) {
            expect(pPLD(Message<Any>::convert<AddPlugin>(msg)).getJson().empty());
        }

        beginTest("Json value of the wrong type");
        json j = {{"id", 5}};
        expect(jsonGetValue(j, "id", String("default")) == "default");
        expect(jsonGetValue(j, "id", 0) == 5);

        beginTest("Non-ASCII text");
        String text(CharPointer_UTF8("caf\xc3\xa9 \xe6\x97\xa5\xe6\x9c\xac"));
        Message<Clipboard> clipOut(&tag), clipIn(&tag);
        PLD(clipOut).setString(text);
        expect(clipOut.send(&clnt));
        expect(clipIn.read(srv.get(), &e), "read failed: " + e.toString());
        expect(PLD(clipIn).getString() == text, "got '" + PLD(clipIn).getString() + "'");
        expect(factory.sendResult(&clnt, 42, text));
        auto res = factory.getResult(srv.get(), 5, &e);
        expect(nullptr != res, "read failed: " + e.toString());
        if (nullptr != res) {
            expect(res->getReturnCode() == 42 && res->getString() == text, "got '" + res->getString() + "'");
        }

        beginTest("Audio message");
        auto meter = Metrics::getStatistic<Meter>("NetBytesIn");
        AudioMessage audioOut(&tag), audioIn(&tag);
        AudioBuffer<float> buf(2, 64), bufF;
        AudioBuffer<double> bufD;
        setBufferSamples(buf, 0.25f);
        MidiBuffer midi, midiIn;
        midi.addEvent(MidiMessage::noteOn(1, 60, 1.0f), 10);
        AudioPlayHead::PositionInfo pos, posIn;
        Uuid traceId;
        expect(audioOut.sendToServer(&clnt, buf, midi, pos, 2, 64, &e, *meter));
        expect(audioIn.readFromClient(srv.get(), bufF, bufD, midiIn, posIn, &e, *meter, traceId), e.toString());
        expect(bufF.getNumChannels() == 2 && bufF.getNumSamples() == 64 && bufF.getSample(1, 63) == 0.25f);
        expect(midiIn.getNumEvents() == 1);

        beginTest("Audio header with invalid counts");
        AudioMessage::RequestHeader h = {};
        h.channels = h.channelsRequested = 2;
        h.samples = h.samplesRequested = -1;
        clnt.write(&h, sizeof(h));
        expect(!audioIn.readFromClient(srv.get(), bufF, bufD, midiIn, posIn, &e, *meter, traceId) &&
                   e.code == MessageHelper::E_DATA,
               "negative sample count accepted: " + e.toString());
        h.samples = h.samplesRequested = 1 << 30;
        clnt.write(&h, sizeof(h));
        expect(!audioIn.readFromClient(srv.get(), bufF, bufD, midiIn, posIn, &e, *meter, traceId) &&
                   e.code == MessageHelper::E_DATA,
               "huge sample count accepted: " + e.toString());
    }
};

static MessageTest messageTest;

}  // namespace e47

#endif  // _MESSAGETEST_HPP_
