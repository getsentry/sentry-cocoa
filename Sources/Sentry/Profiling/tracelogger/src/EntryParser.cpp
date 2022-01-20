// Copyright (c) Specto Inc. All rights reserved.

#include "EntryParser.h"

#include "PacketReader.h"
//#include "spectoproto./entry/entry_generated.pb.h"

#include <cassert>

using namespace specto;
using namespace specto::internal;

namespace specto {

static constexpr int kPacketBufferPoolSize = 8;
namespace {
void appendToBuffer(PacketBuffer &buffer, const Packet *const packet) {
    const auto previousSize = buffer.data.size();
    const auto newSize = previousSize + packet->header.size;
    buffer.data.resize(newSize);

    const auto data = buffer.data.data();
    std::memcpy(data + previousSize, packet->data, packet->header.size);
}
}; // namespace

EntryParser::EntryParser(std::shared_ptr<PacketReader> packetReader) :
    packetReader_(std::move(packetReader)),
    bufferPool_(kPacketBufferPoolSize, []() { return internal::PacketBuffer(); }),
    currentBuffers_() {
    assert(packetReader_ != nullptr);
}

void EntryParser::parse(const EntryParser::Callback &f) {
    packetReader_->read([f, this](const Packet *packets, std::size_t count) {
        return this->parse(f, packets, count);
    });
}

std::size_t
  EntryParser::parse(const EntryParser::Callback &f, const Packet *packets, std::size_t count) {
    assert(packets != nullptr);

    decltype(count) consumedPackets = 0;
    for (std::size_t i = 0; i < count; i++) {
        const Packet *const packet = &packets[i];
        if (packet->header.index == 0) {
            consumedPackets++;
            if (!packet->header.hasNext) {
                // The entry only has a single packet, we can emit this right away.
                f(reinterpret_cast<const void *>(packet->data),
                  static_cast<std::size_t>(packet->header.size));
            } else {
                // This is the start of a new stream.
                auto buffer = bufferPool_.get();
                buffer.streamID = packet->header.streamID;
                buffer.nextIndex = 1;
                appendToBuffer(buffer, packet);
                currentBuffers_.push_front(std::move(buffer));
            }
        } else {
            for (auto it = currentBuffers_.begin(); it != currentBuffers_.end(); it++) {
                auto &buffer = *it;
                if (buffer.streamID == packet->header.streamID) {
                    if (buffer.nextIndex == packet->header.index) {
                        appendToBuffer(buffer, packet);
                        consumedPackets++;
                        if (!packet->header.hasNext) {
                            // Have all the packets for this stream, flush the buffer.
                            f(reinterpret_cast<const void *>(buffer.data.data()),
                              static_cast<std::size_t>(buffer.data.size()));
                        } else {
                            // Need more packets, don't recycle the buffer at the end.
                            buffer.nextIndex++;
                            break;
                        }
                    }
                    auto tempBuffer = std::move(*it);
                    currentBuffers_.erase(it);
                    tempBuffer.data.clear();
                    bufferPool_.recycle(std::move(tempBuffer));
                    break;
                }
            }
        }
    }
    return consumedPackets;
}

} // namespace specto
