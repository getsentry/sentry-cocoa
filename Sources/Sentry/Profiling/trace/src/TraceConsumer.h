// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/traceid/src/TraceID.h"

#include <cstddef>
#include <memory>

namespace specto {
/**
 * Consumes data that is produced during a trace. For example, a concrete implementation of this
 * type could persist the trace data to disk, or stream events to a server.
 */
class TraceConsumer {
public:
    /**
     * Notifies the consumer that a trace has started.
     *
     * @param id The trace identifier.
     */
    virtual void start(TraceID id) = 0;

    /**
     * Notifies the consumer that the trace has ended.
     *
     * @param successful Whether the trace ended successfully or not. If the trace failed, there
     * will be additional trace events that encode information like the failure reason; these will
     * be passed to `receiveEntry` before `end` is called.
     */
    virtual void end(bool successful) = 0;

    /**
     * Called for each trace entry that is received.
     * @param buf A pointer to the buffer that contains the entry data.
     * @param size The length of the buffer.
     */
    virtual void receiveEntryBuffer(std::shared_ptr<char> buf, std::size_t size) = 0;

    virtual ~TraceConsumer() = 0;
};
} // namespace specto
