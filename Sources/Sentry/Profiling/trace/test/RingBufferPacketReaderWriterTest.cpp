// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/protobuf/src/Protobuf.h"
#include "cpp/ringbuffer/src/RingBuffer.h"
#include "cpp/testutils/src/ProtobufComparison.h"
#include "cpp/testutils/src/TestUtils.h"
#include "cpp/trace/src/RingBufferPacketReader.h"
#include "cpp/trace/src/RingBufferPacketWriter.h"
#include "cpp/tracelogger/src/EntryParser.h"
#include "cpp/tracelogger/src/Packet.h"
#include "cpp/tracelogger/src/TraceLogger.h"

#include <limits>
#include <memory>
#include <random>
#include <thread>

using namespace specto;
using namespace specto::test;

namespace {
void threadFunction(std::shared_ptr<RingBuffer<Packet>> ringBuffer,
                    proto::Entry entry1,
                    proto::Entry entry2) {
    const auto packetWriter = std::make_shared<RingBufferPacketWriter>(std::move(ringBuffer));

    TraceLogger logger(packetWriter, 0);
    logger.log(std::move(entry1));
    logger.log(std::move(entry2));
}
} // namespace

TEST(RingBufferPacketReaderWriterTest, TestReadWrite) {
    const auto ringBuffer = std::make_shared<RingBuffer<Packet>>(1, 100);
    const auto packetReader = std::make_shared<RingBufferPacketReader>(ringBuffer);

    auto entry1 = protobuf::makeEntry(proto::Entry_Type_TRACE_START);
    entry1.set_string_value(randomString(300));

    auto entry2 = protobuf::makeEntry(proto::Entry_Type_BACKTRACE);
    entry2.mutable_backtrace()->set_thread_name("foo");
    std::random_device rd;
    std::mt19937_64 gen(rd());
    std::uniform_int_distribution<unsigned long long> dist;
    for (int i = 0; i < 100; i++) {
        entry2.mutable_backtrace()->add_addresses(dist(gen));
    }

    EntryParser parser(packetReader);
    std::thread thread(threadFunction, ringBuffer, entry1, entry2);
    thread.detach();

    bool receivedTraceStartEntry = false;
    bool receivedBacktraceEntry = false;
    while (!receivedTraceStartEntry || !receivedBacktraceEntry) {
        parser.parse([&](auto buf, auto size) {
            proto::Entry entry;
            entry.ParseFromArray(buf, size);
            switch (entry.type()) {
                case proto::Entry_Type_TRACE_START:
                    receivedTraceStartEntry = true;
                    EXPECT_TRUE(compareProtobufAndReport(entry1, entry));
                    break;
                case proto::Entry_Type_BACKTRACE:
                    receivedBacktraceEntry = true;
                    EXPECT_TRUE(compareProtobufAndReport(entry2, entry));
                    break;
                default:
                    break;
            }
        });
    }
    EXPECT_TRUE(receivedTraceStartEntry);
    EXPECT_TRUE(receivedBacktraceEntry);
}

TEST(RingBufferPacketReaderWriterTest, TestIncrementsDropCounterWhenPacketsDropped) {
    const auto ringBuffer = std::make_shared<RingBuffer<Packet>>(1, 1 /* 1 slot */);
    EXPECT_EQ(ringBuffer->getDropCounter(), 0);

    const auto packetReader = std::make_shared<RingBufferPacketReader>(ringBuffer);
    const auto packetWriter = std::make_shared<RingBufferPacketWriter>(ringBuffer);
    TraceLogger traceLogger(packetWriter, 0);

    auto entry1 = protobuf::makeEntry(proto::Entry_Type_TRACE_START);
    entry1.set_string_value(randomString(10));
    traceLogger.log(std::move(entry1));
    EXPECT_EQ(ringBuffer->getDropCounter(), 0);

    auto entry2 = protobuf::makeEntry(proto::Entry_Type_TRACE_START);
    entry1.set_string_value(randomString(10));
    traceLogger.log(std::move(entry2));
    EXPECT_EQ(ringBuffer->getDropCounter(), 1);
}
