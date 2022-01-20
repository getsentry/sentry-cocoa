// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "TraceFileManager.h"
#include "TraceConsumer.h"
#include "spimpl.h"

#include <memory>

namespace specto {
class TraceFileWriter;

/**
 * A trace consumer that writes to files.
 */
class TraceFileTraceConsumer : public TraceConsumer {
public:
    /**
     * Creates a new instance of `TraceFileTraceConsumer`
     * @param fileManager The file manager used to coordinate where to write the trace files to.
     * @param synchronous Whether I/O should be performed synchronously instead of asynchronously.
     */
    TraceFileTraceConsumer(std::shared_ptr<TraceFileManager> fileManager, bool synchronous);

    /** Overridden methods from `TraceConsumer`. */
    void start(TraceID id) override;
    void end(bool successful) override;
    void receiveEntryBuffer(std::shared_ptr<char> buf, std::size_t size) override;

    TraceFileTraceConsumer(const TraceFileTraceConsumer &) = delete;
    TraceFileTraceConsumer &operator=(const TraceFileTraceConsumer &) = delete;

private:
    class Impl;
    spimpl::unique_impl_ptr<Impl> impl_;
};

} // namespace specto
