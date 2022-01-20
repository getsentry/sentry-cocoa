// Copyright (c) Specto Inc. All rights reserved.

#include "TestPacketWriter.h"

namespace specto::test {

TestPacketWriter::TestPacketWriter() : packets_() { }

void TestPacketWriter::write(const PacketSpec *specs, std::size_t count) {
    for (decltype(count) i = 0; i < count; i++) {
        const auto spec = &specs[i];
        Packet packet;
        packet.header = spec->header;
        std::memcpy(packet.data, spec->data, spec->header.size);
        packets_.push_back(packet);
    }
}

std::vector<Packet> TestPacketWriter::packets() const {
    return packets_;
}

} // namespace specto::test
