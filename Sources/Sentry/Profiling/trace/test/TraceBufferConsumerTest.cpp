// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/protobuf/src/Protobuf.h"
#include "cpp/ringbuffer/src/RingBuffer.h"
#include "cpp/trace/src/RingBufferPacketReader.h"
#include "cpp/trace/src/RingBufferPacketWriter.h"
#include "cpp/trace/src/TraceBufferConsumer.h"
#include "cpp/trace/testutils/TestTraceConsumer.h"
#include "cpp/trace/testutils/TestTraceEventObserver.h"
#include "cpp/tracelogger/src/EntryParser.h"
#include "cpp/tracelogger/src/Packet.h"
#include "cpp/tracelogger/src/TraceLogger.h"

#include <atomic>
#include <memory>
#include <thread>

using namespace specto;
using namespace specto::test;

namespace {
std::atomic_bool sDidExitLoop {false};

void consumerThreadFunction(std::shared_ptr<TraceBufferConsumer> consumer) {
    consumer->startLoop();
    sDidExitLoop = true;
}
} // namespace

TEST(TraceBufferConsumerTest, TestNotify) {
    const auto traceBufferConsumer = std::make_shared<TraceBufferConsumer>();

    std::thread thread(consumerThreadFunction, traceBufferConsumer);
    thread.detach();

    const auto ringBuffer = std::make_shared<RingBuffer<Packet>>(1, 100);
    const auto packetWriter = std::make_shared<RingBufferPacketWriter>(std::move(ringBuffer));
    TraceLogger logger(packetWriter, 0);
    logger.log(protobuf::makeEntry(proto::Entry_Type_TRACE_START));
    logger.log(protobuf::makeEntry(proto::Entry_Type_TRACE_END));

    const auto consumer = std::make_shared<TestTraceConsumer>();
    const auto packetReader = std::make_shared<RingBufferPacketReader>(ringBuffer);
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::atomic_bool calledCompletionHandler = false;
    traceBufferConsumer->notify(
      entryParser, consumer, [&calledCompletionHandler]() { calledCompletionHandler = true; });

    bool receivedTraceStartEntry = false;
    bool receivedTraceEndEntry = false;
    while (!calledCompletionHandler) {
    }
    for (const auto &entry : consumer->entries()) {
        switch (entry.type()) {
            case proto::Entry_Type_TRACE_START:
                receivedTraceStartEntry = true;
                break;
            case proto::Entry_Type_TRACE_END:
                receivedTraceEndEntry = true;
                break;
            default:
                break;
        }
    }
    EXPECT_TRUE(calledCompletionHandler);
    EXPECT_TRUE(receivedTraceStartEntry);
    EXPECT_TRUE(receivedTraceEndEntry);
}

TEST(TraceBufferConsumerTest, TestStopLoop) {
    const auto traceBufferConsumer = std::make_shared<TraceBufferConsumer>();

    sDidExitLoop = false;
    std::thread thread(consumerThreadFunction, traceBufferConsumer);
    thread.detach();

    std::atomic_bool loopExitCallbackCalled {false};
    traceBufferConsumer->stopLoop([&loopExitCallbackCalled]() { loopExitCallbackCalled = true; });

    while (!sDidExitLoop || !loopExitCallbackCalled) {
    }
    EXPECT_TRUE(sDidExitLoop);
    EXPECT_TRUE(loopExitCallbackCalled);
}

TEST(TraceBufferConsumerTest, TestIsConsuming) {
    const auto traceBufferConsumer = std::make_shared<TraceBufferConsumer>();
    EXPECT_FALSE(traceBufferConsumer->isConsuming());

    std::thread thread(consumerThreadFunction, traceBufferConsumer);
    thread.detach();

    const auto ringBuffer = std::make_shared<RingBuffer<Packet>>(1, 100);
    const auto consumer = std::make_shared<TestTraceConsumer>();
    const auto packetReader = std::make_shared<RingBufferPacketReader>(ringBuffer);
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::atomic_bool didNotify = false;
    traceBufferConsumer->notify(entryParser, consumer, [&didNotify]() { didNotify = true; });
    while (!didNotify) {
    }
    EXPECT_TRUE(traceBufferConsumer->isConsuming());

    std::atomic_bool loopExitCallbackCalled {false};
    traceBufferConsumer->stopLoop([&loopExitCallbackCalled]() { loopExitCallbackCalled = true; });
    while (!loopExitCallbackCalled) {
    }
    EXPECT_FALSE(traceBufferConsumer->isConsuming());
}
