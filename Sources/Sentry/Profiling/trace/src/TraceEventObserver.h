// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "cpp/traceid/src/TraceID.h"
#include "spectoproto/error/error_generated.pb.h"

namespace specto {
/** Notified of trace state change events (start, end, timeout, etc.). */
class TraceEventObserver {
public:
    /** Called when a new trace starts. */
    virtual void traceStarted(__unused TraceID traceID) { }

    /** Called when a trace ends successfully. */
    virtual void traceEnded(__unused TraceID traceID) { }

    /** Called when a trace fails, with an error object containing the failure reason. */
    virtual void traceFailed(__unused TraceID traceID, __unused const proto::Error &error) { }

    virtual ~TraceEventObserver() = 0;
};
} // namespace specto
