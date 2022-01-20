// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "Packet.h"
#include "PacketStreamID.h"
#include "cpp/util/src/Pool.h"

#include <cstddef>
#include <functional>
#include <list>
#include <memory>
#include <vector>

namespace specto {

class PacketReader;

namespace proto {
class Entry;
}

namespace internal {
struct PacketBuffer {
    PacketStreamID::Type streamID;
    std::uint16_t nextIndex;
    std::vector<std::uint8_t> data;

    PacketBuffer() = default;
    PacketBuffer(const PacketBuffer &) = delete;
    PacketBuffer &operator=(const PacketBuffer &) = delete;
    PacketBuffer(PacketBuffer &&) = default;
    PacketBuffer &operator=(PacketBuffer &&) = default;
};
} // namespace internal

/**
 * Constructs `Entry` structures from a stream of `Packet`s read via a
 * `PacketReader`.
 */
class EntryParser {
public:
    using Callback = std::function<void(const void *buf, std::size_t size)>;

    /**
     * Constructs a new `EntryParser` that parses entries from the specified
     * packet reader.
     *
     * @param packetReader The packet reader to read packets from.
     */
    explicit EntryParser(std::shared_ptr<PacketReader> packetReader);

    EntryParser(const EntryParser &) = delete;
    EntryParser &operator=(const EntryParser &) = delete;
    EntryParser(EntryParser &&) = default;
    EntryParser &operator=(EntryParser &&) = default;

    /**
     * Parses entries if available, and calls `readerFunc` once for
     * each parsed entry. If there are no entries available, this
     * function will not be called.
     *
     * @param f Function that is called for each entry that is parsed.
     */
    void parse(const Callback &f);

private:
    std::shared_ptr<PacketReader> packetReader_;
    specto::util::Pool<internal::PacketBuffer> bufferPool_;
    std::list<internal::PacketBuffer> currentBuffers_;

    std::size_t parse(const Callback &f, const Packet *packets, std::size_t count);
};

} // namespace specto
