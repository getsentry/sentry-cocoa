// Copyright (c) Specto Inc. All rights reserved.

#include "cpp/trace/src/TraceEventObserver.h"

namespace specto {
namespace test {
class TestTraceEventObserver : public TraceEventObserver {
public:
    void traceStarted(TraceID traceID) override;
    void traceEnded(TraceID traceID) override;
    void traceFailed(TraceID traceID, const proto::Error &error) override;

    bool calledTraceStarted = false;
    bool calledTraceEnded = false;
    bool calledTraceFailed = false;
    TraceID lastTraceID = TraceID::empty;
    std::unique_ptr<proto::Error> lastError;
};
} // namespace test
} // namespace specto
