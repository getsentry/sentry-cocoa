// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "TraceEventObserver.h"

#include <functional>
#include <memory>
#include <mutex>
#include <vector>

namespace specto {
/** Broadcasts trace events to a list of observers. */
class TraceEventSubject : public TraceEventObserver {
public:
    /** Add a new observer to be notified on trace events. */
    void addObserver(std::shared_ptr<TraceEventObserver> observer);
    /** Remove a previously registered observer. */
    void removeObserver(std::shared_ptr<TraceEventObserver> observer);

    /** All of the trace event methods are forwarded to the list of observers. */
    void traceStarted(TraceID traceID) override;
    void traceEnded(TraceID traceID) override;
    void traceFailed(TraceID traceID, const proto::Error &error) override;

    TraceEventSubject();
    TraceEventSubject(const TraceEventSubject &) = delete;
    TraceEventSubject &operator=(const TraceEventSubject &) = delete;

private:
    void forEachObserver(
      const std::function<void(const std::shared_ptr<TraceEventObserver> &)> &f) const;

    std::vector<std::weak_ptr<TraceEventObserver>> observers_;
    mutable std::mutex observersLock_;
};
} // namespace specto
