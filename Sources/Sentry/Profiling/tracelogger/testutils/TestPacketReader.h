// Copyright (c) Specto Inc. All rights reserved.

#include "cpp/tracelogger/src/PacketReader.h"

#include <cstddef>
#include <vector>

#pragma once

namespace specto::test {

/** A packet reader that reads from a vector of packets, for unit testing purposes. */
class TestPacketReader : public PacketReader {
public:
    explicit TestPacketReader(std::vector<Packet> packets);

    TestPacketReader(const TestPacketReader &) = delete;
    TestPacketReader &operator=(const TestPacketReader &) = delete;
    TestPacketReader(TestPacketReader &&) = default;
    TestPacketReader &operator=(TestPacketReader &&) = default;

    void read(std::function<size_t(const Packet *packets, std::size_t count)> readFunc) override;

private:
    std::vector<Packet> packets_;
};

} // namespace specto::test
