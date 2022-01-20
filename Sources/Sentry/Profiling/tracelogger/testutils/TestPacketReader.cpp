// Copyright (c) Specto Inc. All rights reserved.

#include "TestPacketReader.h"

namespace specto::test {

TestPacketReader::TestPacketReader(std::vector<Packet> packets) : packets_(std::move(packets)) { }

void TestPacketReader::read(
  std::function<size_t(const Packet *packets, std::size_t count)> readFunc) {
    readFunc(packets_.data(), packets_.size());
}

} // namespace specto::test
