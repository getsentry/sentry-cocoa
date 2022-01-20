// Copyright (c) Specto Inc. All rights reserved.

#include "TestTraceEventObserver.h"

namespace specto::test {

void TestTraceEventObserver::traceStarted(TraceID traceID) {
    calledTraceStarted = true;
    lastTraceID = traceID;
}

void TestTraceEventObserver::traceEnded(TraceID traceID) {
    calledTraceEnded = true;
    lastTraceID = traceID;
}

void TestTraceEventObserver::traceFailed(TraceID traceID, const proto::Error &error) {
    calledTraceFailed = true;
    lastTraceID = traceID;
    lastError = std::make_unique<proto::Error>(error);
}

} // namespace specto::test
