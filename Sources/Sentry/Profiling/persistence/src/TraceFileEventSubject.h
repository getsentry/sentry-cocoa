// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include "TraceFileEventObserver.h"

#include <functional>
#include <memory>
#include <mutex>
#include <vector>

namespace specto {
/** Broadcasts file manager events to a list of observers. */
class TraceFileEventSubject : public TraceFileEventObserver {
public:
    /** Add a new observer to be notified on file manager events. */
    void addObserver(std::shared_ptr<TraceFileEventObserver> observer);
    /** Remove a previously registered observer. */
    void removeObserver(std::shared_ptr<TraceFileEventObserver> observer);

    /** All of the event methods are forwarded to the list of observers. */
    void traceFileCompleted(const filesystem::Path &oldPath,
                            const filesystem::Path &newPath) override;
    void traceFileUploadQueued(const filesystem::Path &oldPath,
                               const filesystem::Path &newPath) override;
    void traceFileUploadCancelled(const filesystem::Path &oldPath,
                                  const filesystem::Path &newPath) override;
    void traceFileUploadFinished(const filesystem::Path &oldPath) override;
    void traceFilePruned(const filesystem::Path &oldPath) override;

    TraceFileEventSubject();
    TraceFileEventSubject(const TraceFileEventSubject &) = delete;
    TraceFileEventSubject &operator=(const TraceFileEventSubject &) = delete;

private:
    void forEachObserver(
      const std::function<void(const std::shared_ptr<TraceFileEventObserver> &)> &f) const;

    std::vector<std::weak_ptr<TraceFileEventObserver>> observers_;
    mutable std::mutex observersLock_;
};
} // namespace specto
