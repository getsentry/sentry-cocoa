// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/time/src/Time.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <functional>
#include <memory>
#include <type_traits>

namespace specto {

class PacketWriter;

/**
 * Async signal safe TraceLogger that logs trace entries as packets.
 *
 * @note Can only be used from one thread at a time.
 */
class TraceLogger {
public:
    /**
     * The maximum size, in bytes, for a single entry. Exceeding this size will cause an
     * error to be logged, and the trace entry will not be written.
     */
    static const std::size_t kMaxEntrySize = 2048;

    /**
     * Construct a new TraceLogger that writes to the specified packet writer.
     *
     * @param writer The packet writer to write to.
     * @param referenceUptimeNs The current device uptime. Stored as a reference
     * for computing relative timestamps of entries logged by this instance.
     * @param onLog An optional function to call after each call to `log`, used to
     * inject side effects.
     */
    TraceLogger(std::shared_ptr<PacketWriter> writer,
                time::Type referenceUptimeNs,
                std::function<void(void)> onLog = nullptr);

    TraceLogger(const TraceLogger &) = delete;
    TraceLogger &operator=(const TraceLogger &) = delete;
    TraceLogger(TraceLogger &&) = default;
    TraceLogger &operator=(TraceLogger &&) = default;

    /**
     * Logs a trace entry. The entry timestamp will be overwritten with the
     * time relative to the logger's reference time. The maximum serialized
     * size of the entry cannot be larger than `kMaxEntrySize` bytes.
     *
     * @param entry The entry to log.
     */
    void log(specto::proto::Entry entry) const;

    /**
     * Unsafe API for logging a trace entry from a byte buffer. The byte
     * buffer must contain valid serialized proto data -- no additional checking
     * is performed by this method.
     *
     * @param buf Pointer to the buffer containing the serialized entry proto data.
     * @param size The length of the buffer.
     */
    void unsafeLogBytes(const char *buf, std::size_t size) const;

    /**
     * Invalidates this logger such that all future calls to `log()` will be
     * a no-op.
     */
    void invalidate();

    /**
     * @return The reference uptime that the `TraceLogger` was initialized with.
     */
    time::Type referenceUptimeNs() const;

private:
    std::shared_ptr<PacketWriter> writer_;
    time::Type referenceUptimeNs_;
    std::function<void(void)> onLog_;

    void
      write(const char *buf, std::size_t size, const std::shared_ptr<PacketWriter> &writer) const;
};

} // namespace specto
