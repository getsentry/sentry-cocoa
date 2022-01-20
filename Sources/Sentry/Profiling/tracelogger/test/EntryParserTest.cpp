// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/testutils/src/ProtobufComparison.h"
#include "cpp/testutils/src/TestUtils.h"
#include "cpp/tracelogger/src/EntryParser.h"
#include "cpp/tracelogger/testutils/TestPacketReader.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <cstddef>
#include <cstdint>
#include <iterator>
#include <limits>
#include <memory>
#include <random>

using namespace specto;
using namespace specto::test;

namespace {

constexpr auto GROUP_UUID = "3319B58E-EDF0-4344-A7CA-8631752F48F8";

std::vector<Packet> createPackets(const char *const buf,
                                  std::size_t length,
                                  std::size_t numPackets,
                                  PacketStreamID::Type streamID = 0) {
    std::vector<Packet> packets;
    const auto packetSize = (numPackets == 0) ? sizeof(Packet::data) : (length / numPackets);
    std::size_t packetCount;
    if (numPackets == 0) {
        packetCount = (length + sizeof(Packet::data) - 1) / sizeof(Packet::data);
    } else {
        packetCount = numPackets;
    }
    auto offset = 0;
    for (std::size_t i = 0; i < (packetCount - 1); i++) {
        auto packet = Packet {
          .header =
            {
              .streamID = streamID,
              .index = static_cast<std::uint16_t>(i),
              .hasNext = true,
              .size = static_cast<std::uint16_t>(packetSize),
            },
          .data = {},
        };
        std::memcpy(packet.data, buf + offset, packetSize);
        packets.push_back(packet);
        offset += packetSize;
    }

    const auto lastPacketSize = length - offset;
    auto lastPacket = Packet {
      .header =
        {
          .streamID = streamID,
          .index = static_cast<std::uint16_t>(packetCount - 1),
          .hasNext = false,
          .size = static_cast<std::uint16_t>(lastPacketSize),
        },
      .data = {},
    };
    std::memcpy(lastPacket.data, buf + offset, lastPacketSize);
    packets.push_back(lastPacket);
    return packets;
}
} // namespace

TEST(EntryParserTest, TestReadSinglePacketEntry) {
    const auto message = randomString(60);

    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(1);
    entry.set_tid(2);
    entry.set_type(proto::Entry_Type_TRACE_START);
    entry.set_group_id(GROUP_UUID);
    entry.set_string_value(message);

    const auto size = entry.ByteSizeLong();
    const auto numPackets = (size + sizeof(Packet::data) - 1) / sizeof(Packet::data);
    EXPECT_EQ(numPackets, 1);
    char buf[size];
    entry.SerializeToArray(buf, size);

    const auto packetReader =
      std::make_shared<TestPacketReader>(createPackets(buf, size, numPackets));
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::size_t entryCount = 0;
    entryParser->parse([&](auto buf, auto size) {
        entryCount++;
        proto::Entry parsedEntry;
        parsedEntry.ParseFromArray(buf, static_cast<int>(size));
        EXPECT_TRUE(compareProtobufAndReport(entry, parsedEntry));
    });
    EXPECT_EQ(entryCount, 1);
}

TEST(EntryParserTest, TestReadDoublePacketEntry) {
    const auto message = randomString(80);

    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(1);
    entry.set_tid(2);
    entry.set_type(proto::Entry_Type_TRACE_START);
    entry.set_group_id(GROUP_UUID);
    entry.set_string_value(message);

    const auto size = entry.ByteSizeLong();
    const auto numPackets = (size + sizeof(Packet::data) - 1) / sizeof(Packet::data);
    EXPECT_EQ(numPackets, 2);
    char buf[size];
    entry.SerializeToArray(buf, size);

    const auto packetReader =
      std::make_shared<TestPacketReader>(createPackets(buf, size, numPackets));
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::size_t entryCount = 0;
    entryParser->parse([&](auto buf, auto size) {
        entryCount++;
        proto::Entry parsedEntry;
        parsedEntry.ParseFromArray(buf, static_cast<int>(size));
        EXPECT_TRUE(compareProtobufAndReport(entry, parsedEntry));
    });
    EXPECT_EQ(entryCount, 1);
}

TEST(EntryParserTest, TestTriplePacketEntry) {
    const auto message = randomString(200);

    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(1);
    entry.set_tid(2);
    entry.set_type(proto::Entry_Type_TRACE_START);
    entry.set_group_id(GROUP_UUID);
    entry.set_string_value(message);

    const auto size = entry.ByteSizeLong();
    char buf[size];
    const auto numPackets = (size + sizeof(Packet::data) - 1) / sizeof(Packet::data);
    EXPECT_EQ(numPackets, 3);
    entry.SerializeToArray(buf, size);

    const auto packetReader =
      std::make_shared<TestPacketReader>(createPackets(buf, size, numPackets));
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::size_t entryCount = 0;
    entryParser->parse([&](auto buf, auto size) {
        entryCount++;
        proto::Entry parsedEntry;
        parsedEntry.ParseFromArray(buf, static_cast<int>(size));
        EXPECT_TRUE(compareProtobufAndReport(entry, parsedEntry));
    });
    EXPECT_EQ(entryCount, 1);
}

TEST(EntryParserTest, TestReadMultipleEntries) {
    const auto message1 = randomString(80);

    proto::Entry entry1;
    entry1.set_elapsed_relative_to_start_date_ns(1);
    entry1.set_tid(2);
    entry1.set_type(proto::Entry_Type_TRACE_START);
    entry1.set_group_id(GROUP_UUID);
    entry1.set_string_value(message1);

    const auto size1 = entry1.ByteSizeLong();
    const auto numPackets1 = (size1 + sizeof(Packet::data) - 1) / sizeof(Packet::data);
    char buf1[size1];
    entry1.SerializeToArray(buf1, size1);

    const auto message2 = randomString(80);

    proto::Entry entry2;
    entry2.set_elapsed_relative_to_start_date_ns(2);
    entry2.set_tid(2);
    entry2.set_type(proto::Entry_Type_TRACE_END);
    entry2.set_group_id(GROUP_UUID);
    entry2.set_string_value(message2);

    const auto size2 = entry2.ByteSizeLong();
    const auto numPackets2 = (size2 + sizeof(Packet::data) - 1) / sizeof(Packet::data);
    char buf2[size2];
    entry2.SerializeToArray(buf2, size2);

    auto packets = createPackets(buf1, size1, numPackets1, 0);
    const auto stream1Packets = createPackets(buf2, size2, numPackets2, 1);
    packets.insert(packets.end(),
                   std::make_move_iterator(stream1Packets.begin()),
                   std::make_move_iterator(stream1Packets.end()));

    const auto packetReader = std::make_shared<TestPacketReader>(std::move(packets));
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::size_t entryCount = 0;
    entryParser->parse([&](auto buf, auto size) {
        entryCount++;
        proto::Entry parsedEntry;
        parsedEntry.ParseFromArray(buf, static_cast<int>(size));
        if (entryCount == 1) {
            EXPECT_TRUE(compareProtobufAndReport(entry1, parsedEntry));
        } else {
            EXPECT_TRUE(compareProtobufAndReport(entry2, parsedEntry));
        }
    });
    EXPECT_EQ(entryCount, 2);
}

TEST(EntryParserTest, TestSkipsPacketWithMismatchedIndex) {
    const auto message = randomString(60);

    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(1);
    entry.set_tid(2);
    entry.set_type(proto::Entry_Type_TRACE_START);
    entry.set_group_id(GROUP_UUID);
    entry.set_string_value(message);

    const auto size = entry.ByteSizeLong();
    // const auto numPackets = (size + sizeof(Packet::data) -1) / sizeof(Packet::data);
    char buf[size];
    entry.SerializeToArray(buf, size);

    std::vector<Packet> packets;
    auto packet1 = Packet {
      .header =
        {
          .streamID = 0,
          .index = 0,
          .hasNext = true,
          .size = static_cast<uint16_t>(size),
        },
      .data = {},
    };
    std::memcpy(packet1.data, buf, size);
    packets.push_back(packet1);

    auto packet2 = Packet {
      .header =
        {
          .streamID = 0,
          .index = 2,
          .hasNext = false,
          .size = 1,
        },
      .data = {124},
    };
    packets.push_back(packet2);

    const auto packetReader = std::make_shared<TestPacketReader>(std::move(packets));
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::size_t entryCount = 0;
    entryParser->parse([&](__unused auto buf, __unused auto size) { entryCount++; });
    EXPECT_EQ(entryCount, 0);
}

TEST(EntryParserTest, TestSkipsPacketWithMismatchedStreamID) {
    const auto message = randomString(60);

    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(1);
    entry.set_tid(2);
    entry.set_type(proto::Entry_Type_TRACE_START);
    entry.set_group_id(GROUP_UUID);
    entry.set_string_value(message);

    const auto size = entry.ByteSizeLong();
    char buf[size];
    entry.SerializeToArray(buf, size);

    std::vector<Packet> packets;
    auto packet1 = Packet {
      .header =
        {
          .streamID = 0,
          .index = 0,
          .hasNext = true,
          .size = static_cast<uint16_t>(size),
        },
      .data = {},
    };
    std::memcpy(packet1.data, buf, size);
    packets.push_back(packet1);

    auto packet2 = Packet {
      .header =
        {
          .streamID = 1,
          .index = 1,
          .hasNext = false,
          .size = 1,
        },
      .data = {124},
    };
    packets.push_back(packet2);

    const auto packetReader = std::make_shared<TestPacketReader>(std::move(packets));
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::size_t entryCount = 0;
    entryParser->parse([&](__unused auto buf, __unused auto size) { entryCount++; });
    EXPECT_EQ(entryCount, 0);
}

TEST(EntryParserTest, TestIgnoresPreviousIncompleteStream) {
    const auto message = randomString(60);

    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(1);
    entry.set_tid(2);
    entry.set_type(proto::Entry_Type_TRACE_START);
    entry.set_group_id(GROUP_UUID);
    entry.set_string_value(message);

    const auto size = entry.ByteSizeLong();
    char buf[size];
    entry.SerializeToArray(buf, size);

    std::vector<Packet> packets;
    auto packet1 = Packet {
      .header =
        {
          .streamID = 0,
          .index = 0,
          .hasNext = true,
          .size = 1,
        },
      .data = {123},
    };
    packets.push_back(packet1);

    auto packet2 = Packet {
      .header =
        {
          .streamID = 1,
          .index = 0,
          .hasNext = false,
          .size = static_cast<uint16_t>(size),
        },
      .data = {},
    };
    std::memcpy(packet2.data, buf, size);
    packets.push_back(packet2);

    const auto packetReader = std::make_shared<TestPacketReader>(std::move(packets));
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::size_t entryCount = 0;
    entryParser->parse([&](auto buf, auto size) {
        entryCount++;
        proto::Entry parsedEntry;
        parsedEntry.ParseFromArray(buf, static_cast<int>(size));
        EXPECT_TRUE(compareProtobufAndReport(entry, parsedEntry));
    });
    EXPECT_EQ(entryCount, 1);
}

TEST(EntryParserTest, TestHandlesMultipleConcurrentStreams) {
    const auto message1 = randomString(60);

    proto::Entry entry1;
    entry1.set_elapsed_relative_to_start_date_ns(1);
    entry1.set_tid(2);
    entry1.set_type(proto::Entry_Type_TRACE_START);
    entry1.set_group_id(GROUP_UUID);
    entry1.set_string_value(message1);

    const auto size1 = entry1.ByteSizeLong();
    char buf1[size1];
    entry1.SerializeToArray(buf1, size1);

    const auto message2 = randomString(60);

    proto::Entry entry2;
    entry2.set_elapsed_relative_to_start_date_ns(2);
    entry2.set_tid(2);
    entry2.set_type(proto::Entry_Type_TRACE_END);
    entry2.set_group_id(GROUP_UUID);
    entry2.set_string_value(message2);

    const auto size2 = entry2.ByteSizeLong();
    char buf2[size2];
    entry2.SerializeToArray(buf2, size2);

    auto packets = createPackets(buf1, size1, 2, 0);
    const auto stream1Packets = createPackets(buf2, size2, 2, 1);
    // Put the packets for the second entry between the first and second
    // packets of the first entry.
    packets.insert(packets.begin() + 1,
                   std::make_move_iterator(stream1Packets.begin()),
                   std::make_move_iterator(stream1Packets.end()));

    const auto packetReader = std::make_shared<TestPacketReader>(std::move(packets));
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::size_t entryCount = 0;
    entryParser->parse([&](auto buf, auto size) {
        entryCount++;
        proto::Entry parsedEntry;
        parsedEntry.ParseFromArray(buf, static_cast<int>(size));
        if (entryCount == 2) {
            EXPECT_TRUE(compareProtobufAndReport(entry1, parsedEntry));
        } else {
            EXPECT_TRUE(compareProtobufAndReport(entry2, parsedEntry));
        }
    });
    EXPECT_EQ(entryCount, 2);
}

TEST(EntryParserTest, TestStressMultipleSequentialStreams) {
    std::vector<Packet> allPackets;
    std::vector<proto::Entry> allEntries;
    for (int i = 0; i < 30; i++) {
        proto::Entry entry;
        entry.set_elapsed_relative_to_start_date_ns(i);
        entry.set_tid(2);
        entry.set_type(proto::Entry_Type_BACKTRACE);
        entry.set_group_id(GROUP_UUID);
        entry.mutable_backtrace()->set_thread_name("foo");
        std::random_device rd;
        std::mt19937_64 gen(rd());
        std::uniform_int_distribution<unsigned long long> dist;
        for (int j = 0; j < 100; j++) {
            entry.mutable_backtrace()->add_addresses(dist(gen));
        }

        const auto size = entry.ByteSizeLong();
        char buf[size];
        entry.SerializeToArray(buf, size);

        const auto packets = createPackets(buf, size, 0, i);
        allPackets.insert(std::end(allPackets), std::begin(packets), std::end(packets));
        allEntries.push_back(std::move(entry));
    }

    const auto packetReader = std::make_shared<TestPacketReader>(std::move(allPackets));
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::size_t entryCount = 0;
    entryParser->parse([&](auto buf, auto size) {
        entryCount++;
        proto::Entry parsedEntry;
        parsedEntry.ParseFromArray(buf, static_cast<int>(size));
        EXPECT_TRUE(compareProtobufAndReport(
          allEntries[parsedEntry.elapsed_relative_to_start_date_ns()], parsedEntry));
    });
    EXPECT_EQ(entryCount, allEntries.size());
}

namespace {
// From https://stackoverflow.com/a/16421677
template<typename Iter, typename RandomGenerator>
Iter select_randomly(Iter start, Iter end, RandomGenerator &g) {
    const auto distance = std::distance(start, end);
    if (distance == 0) {
        return end;
    }
    std::uniform_int_distribution<> dis(0, distance - 1);
    std::advance(start, dis(g));
    return start;
}

template<typename Iter>
Iter select_randomly(Iter start, Iter end) {
    static std::random_device rd;
    static std::mt19937 gen(rd());
    return select_randomly(start, end, gen);
}
} // namespace

TEST(EntryParserTest, TestStressMultipleInterleavedStreams) {
    std::vector<Packet> allPackets;
    std::vector<proto::Entry> allEntries;
    for (int i = 0; i < 30; i++) {
        proto::Entry entry;
        entry.set_elapsed_relative_to_start_date_ns(i);
        entry.set_tid(2);
        entry.set_type(proto::Entry_Type_BACKTRACE);
        entry.set_group_id(GROUP_UUID);
        entry.mutable_backtrace()->set_thread_name("foo");
        std::random_device rd;
        std::mt19937_64 gen(rd());
        std::uniform_int_distribution<unsigned long long> dist;
        for (int j = 0; j < 100; j++) {
            entry.mutable_backtrace()->add_addresses(dist(gen));
        }

        const auto size = entry.ByteSizeLong();
        char buf[size];
        entry.SerializeToArray(buf, size);

        const auto packets = createPackets(buf, size, 0, i);
        allPackets.insert(select_randomly(std::begin(allPackets), std::end(allPackets)),
                          std::begin(packets),
                          std::end(packets));
        allEntries.push_back(std::move(entry));
    }

    const auto packetReader = std::make_shared<TestPacketReader>(std::move(allPackets));
    const auto entryParser = std::make_shared<EntryParser>(packetReader);

    std::size_t entryCount = 0;
    entryParser->parse([&](auto buf, auto size) {
        entryCount++;
        proto::Entry parsedEntry;
        parsedEntry.ParseFromArray(buf, static_cast<int>(size));
        EXPECT_TRUE(compareProtobufAndReport(
          allEntries[parsedEntry.elapsed_relative_to_start_date_ns()], parsedEntry));
    });
    EXPECT_EQ(entryCount, allEntries.size());
}
