// Copyright (c) Specto Inc. All rights reserved.

#include "PacketStreamID.h"

namespace specto {

std::atomic<PacketStreamID::Type> PacketStreamID::streamID_ {0};

PacketStreamID::Type PacketStreamID::getNext() noexcept {
    return streamID_.fetch_add(1, std::memory_order_relaxed);
}

void PacketStreamID::reset() noexcept {
    streamID_ = 0;
}

} // namespace specto
