// Copyright (c) Specto Inc. All rights reserved.

#include "cpp/tracelogger/src/PacketWriter.h"

#include <cstddef>
#include <vector>

#pragma once

namespace specto {
namespace test {

/** A packet writer that exposes a vector of packets, for unit testing purposes. */
class TestPacketWriter : public PacketWriter {
public:
    TestPacketWriter();

    TestPacketWriter(const TestPacketWriter &) = delete;
    TestPacketWriter &operator=(const TestPacketWriter &) = delete;
    TestPacketWriter(TestPacketWriter &&) = default;
    TestPacketWriter &operator=(TestPacketWriter &&) = default;

    void write(const PacketSpec *specs, std::size_t count) override;

    std::vector<Packet> packets() const;

private:
    std::vector<Packet> packets_;
};

} // namespace test
} // namespace specto
