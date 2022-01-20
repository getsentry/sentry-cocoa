// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/protobuf/src/Protobuf.h"
#include "cpp/testutils/src/ProtobufComparison.h"
#include "cpp/testutils/src/TestUtils.h"
#include "cpp/tracelogger/src/TraceLogger.h"
#include "cpp/tracelogger/testutils/TestPacketWriter.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>
#include <memory>

using namespace specto;
using namespace specto::test;

namespace {
constexpr auto GROUP_UUID = "3319B58E-EDF0-4344-A7CA-8631752F48F8";
}

TEST(TraceLoggerTest, WriteOnePacket) {
    const auto message = randomString(60);

    const auto packetWriter = std::make_shared<TestPacketWriter>();
    const auto logger = std::make_shared<TraceLogger>(
      std::static_pointer_cast<PacketWriter, TestPacketWriter>(packetWriter), 0);

    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(1);
    entry.set_tid(2);
    entry.set_type(proto::Entry_Type_TRACE_START);
    entry.set_group_id(GROUP_UUID);
    entry.set_string_value(message);

    logger->log(entry);

    const auto packets = packetWriter->packets();
    EXPECT_EQ(packets.size(), 1);

    const auto packet = packets[0];
    EXPECT_EQ(packet.header.index, 0);
    EXPECT_FALSE(packet.header.hasNext);
    EXPECT_GE(packet.header.size, 60);

    proto::Entry deserializedEntry;
    deserializedEntry.ParseFromArray(packet.data, packet.header.size);
    EXPECT_TRUE(compareProtobufAndReport(entry, deserializedEntry));
}

TEST(TraceLoggerTest, WriteMultiplePackets) {
    const auto message = randomString(160);

    const auto packetWriter = std::make_shared<TestPacketWriter>();
    const auto logger = std::make_shared<TraceLogger>(
      std::static_pointer_cast<PacketWriter, TestPacketWriter>(packetWriter), 0);

    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(1);
    entry.set_tid(2);
    entry.set_type(proto::Entry_Type_TRACE_START);
    entry.set_group_id(GROUP_UUID);
    entry.set_string_value(message);

    logger->log(entry);

    const auto packets = packetWriter->packets();
    EXPECT_EQ(packets.size(), 2);

    const auto firstPacket = packets[0];
    EXPECT_EQ(firstPacket.header.index, 0);
    EXPECT_TRUE(firstPacket.header.hasNext);

    const auto secondPacket = packets[1];
    EXPECT_EQ(secondPacket.header.index, 1);
    EXPECT_FALSE(secondPacket.header.hasNext);

    char packetData[firstPacket.header.size + secondPacket.header.size];
    std::memcpy(packetData, firstPacket.data, firstPacket.header.size);
    std::memcpy(packetData + firstPacket.header.size, secondPacket.data, secondPacket.header.size);

    proto::Entry deserializedEntry;
    deserializedEntry.ParseFromArray(packetData, sizeof(packetData));
    EXPECT_TRUE(compareProtobufAndReport(entry, deserializedEntry));
}

TEST(TraceLoggerTest, TestInvalidate) {
    const auto packetWriter = std::make_shared<TestPacketWriter>();
    const auto logger = std::make_shared<TraceLogger>(
      std::static_pointer_cast<PacketWriter, TestPacketWriter>(packetWriter), 0);

    logger->invalidate();

    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(1);
    entry.set_tid(2);
    entry.set_type(proto::Entry_Type_TRACE_START);
    entry.set_group_id(GROUP_UUID);

    logger->log(std::move(entry));

    const auto packets = packetWriter->packets();
    EXPECT_EQ(packets.size(), 0);
}

TEST(TraceLoggerTest, TestOnLogCalled) {
    const auto packetWriter = std::make_shared<TestPacketWriter>();
    bool calledOnLog = false;
    const auto logger = std::make_shared<TraceLogger>(
      std::static_pointer_cast<PacketWriter, TestPacketWriter>(packetWriter), 0, [&calledOnLog]() {
          calledOnLog = true;
      });

    EXPECT_FALSE(calledOnLog);
    logger->log(protobuf::makeEntry(proto::Entry_Type_TRACE_START));
    EXPECT_TRUE(calledOnLog);
}

TEST(TraceLoggerTest, TestLogUnsafeBytes) {
    const auto message = randomString(60);

    const auto packetWriter = std::make_shared<TestPacketWriter>();
    const auto logger = std::make_shared<TraceLogger>(
      std::static_pointer_cast<PacketWriter, TestPacketWriter>(packetWriter), 0);

    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(1);
    entry.set_tid(2);
    entry.set_type(proto::Entry_Type_TRACE_START);
    entry.set_group_id(GROUP_UUID);
    entry.set_string_value(message);

    const auto size = entry.ByteSizeLong();
    auto buf = new char[size];
    entry.SerializeToArray(buf, size);
    logger->unsafeLogBytes(buf, size);

    const auto packets = packetWriter->packets();
    EXPECT_EQ(packets.size(), 1);

    const auto packet = packets[0];
    EXPECT_EQ(packet.header.index, 0);
    EXPECT_FALSE(packet.header.hasNext);
    EXPECT_GE(packet.header.size, 60);

    proto::Entry deserializedEntry;
    deserializedEntry.ParseFromArray(packet.data, packet.header.size);
    EXPECT_TRUE(compareProtobufAndReport(entry, deserializedEntry));
}
