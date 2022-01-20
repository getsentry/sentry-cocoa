// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/time/src/Time.h"
#include "cpp/traceid/src/TraceID.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <memory>
#include <mutex>

namespace specto {
class TraceBufferConsumer;
class TraceConsumer;

/**
 * A "session" is defined as the time period from when a user opens an application to
 * when the user quits or backgrounds the application. `SessionController` tracks metrics
 * that are associated with an entire session as opposed to a particular trace within a
 * session. Each trace is associated with a particular session.
 */
class SessionController {
public:
    /** Constructs a new session controller. */
    SessionController();

    /** Returns the current session ID, or `TraceID::empty` if there is no current session. */
    TraceID currentSessionID() const;

    /**
     * Starts a new session. Ends an existing session if one is already active.
     * @param consumer The consumer that receives entries logged using `log`
     */
    void startSession(std::shared_ptr<TraceConsumer> consumer);

    /** Ends the current session. No-op if there is no current session. */
    void endSession();

    /**
     * Logs an entry for the current session. Logs a warning and is a no-op if there
     * is no current session.
     *
     * @param entry The entry to log.
     * @note Unlike for traces, entries logged for a session are NOT buffered, as we
     * do not expect high logging throughput for sessions. The consumer passed to `startTrace`
     * will be called synchronously.
     */
    void log(proto::Entry entry) const;

    /**
     * Unsafe API for logging a trace entry from a byte buffer. The byte
     * buffer must contain valid serialized proto data -- no additional checking
     * is performed by this method.
     *
     * @param buf Pointer to the buffer containing the serialized entry proto data.
     * @param size The length of the buffer.
     */
    void unsafeLogBytes(std::shared_ptr<char> buf, std::size_t size) const;

    /**
     * @return The reference time that the `SessionController` was initialized with.
     */
    time::Type referenceUptimeNs() const;

    SessionController(const SessionController &) = delete;
    SessionController &operator=(const SessionController &) = delete;

private:
    /**
     * The public versions of these methods take `lock_` before calling through
     * to these internal implementations.
     */
    void _log(proto::Entry entry) const;
    void _unsafeLogBytes(std::shared_ptr<char> buf, std::size_t size) const;

    std::shared_ptr<TraceConsumer> consumer_;
    TraceID id_;
    time::Type referenceUptimeNs_;
    mutable std::mutex lock_;
};

} // namespace specto
