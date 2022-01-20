// Copyright (c) Specto Inc. All rights reserved.

#include "RingBufferPacketReader.h"

#include "RingBuffer.h"

#include <cassert>

namespace specto {

RingBufferPacketReader::RingBufferPacketReader(std::shared_ptr<RingBuffer<Packet>> buffer) :
    buffer_(std::move(buffer)) {
    assert(buffer_ != nullptr);
}

void RingBufferPacketReader::read(
  std::function<std::size_t(const Packet *packets, std::size_t count)> readFunc) {
    buffer_->consume(readFunc);
}

} // namespace specto
