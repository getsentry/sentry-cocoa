// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "Path.h"

namespace specto {
/** Notified when trace files change their state within the TraceFileManager. */
class TraceFileEventObserver {
public:
    /** Called when a trace file moves from the pending to the completed state. */
    virtual void traceFileCompleted(__unused const filesystem::Path &oldPath,
                                    __unused const filesystem::Path &newPath) { }

    /** Called when a trace file moves from the completed state to the upload queued state. */
    virtual void traceFileUploadQueued(__unused const filesystem::Path &oldPath,
                                       __unused const filesystem::Path &newPath) { }

    /** Called when a trace file moves from the upload queued state back to the completed state. */
    virtual void traceFileUploadCancelled(__unused const filesystem::Path &oldPath,
                                          __unused const filesystem::Path &newPath) { }

    /**
     * Called when a trace file moves from the upload queued state to the upload finished
     * state.
     */
    virtual void traceFileUploadFinished(__unused const filesystem::Path &oldPath) { }

    /** Called when a trace file is deleted due to pruning. */
    virtual void traceFilePruned(__unused const filesystem::Path &oldPath) { }

    virtual ~TraceFileEventObserver() = 0;
};
} // namespace specto
