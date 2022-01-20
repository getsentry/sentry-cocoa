// Copyright (c) Specto Inc. All rights reserved.

#include "TraceFileEventSubject.h"

#include <algorithm>

namespace specto {

void TraceFileEventSubject::addObserver(std::shared_ptr<TraceFileEventObserver> observer) {
    if (observer == nullptr) {
        return;
    }
    std::lock_guard<std::mutex> l(observersLock_);
    observers_.push_back(std::move(observer));
}

void TraceFileEventSubject::removeObserver(std::shared_ptr<TraceFileEventObserver> observer) {
    if (observer == nullptr) {
        return;
    }
    std::lock_guard<std::mutex> l(observersLock_);
    observers_.erase(std::remove_if(observers_.begin(), observers_.end(), [&](const auto &weakPtr) {
        return weakPtr.expired() || weakPtr.lock() == observer;
    }));
}

void TraceFileEventSubject::traceFileCompleted(const filesystem::Path &oldPath,
                                               const filesystem::Path &newPath) {
    forEachObserver([&oldPath, &newPath](const auto &observer) {
        observer->traceFileCompleted(oldPath, newPath);
    });
}

void TraceFileEventSubject::traceFileUploadQueued(const filesystem::Path &oldPath,
                                                  const filesystem::Path &newPath) {
    forEachObserver([&oldPath, &newPath](const auto &observer) {
        observer->traceFileUploadQueued(oldPath, newPath);
    });
}

void TraceFileEventSubject::traceFileUploadCancelled(const filesystem::Path &oldPath,
                                                     const filesystem::Path &newPath) {
    forEachObserver([&oldPath, &newPath](const auto &observer) {
        observer->traceFileUploadCancelled(oldPath, newPath);
    });
}

void TraceFileEventSubject::traceFileUploadFinished(const filesystem::Path &oldPath) {
    forEachObserver(
      [&oldPath](const auto &observer) { observer->traceFileUploadFinished(oldPath); });
}

void TraceFileEventSubject::traceFilePruned(const filesystem::Path &oldPath) {
    forEachObserver([&oldPath](const auto &observer) { observer->traceFilePruned(oldPath); });
}

TraceFileEventSubject::TraceFileEventSubject() = default;

void TraceFileEventSubject::forEachObserver(
  const std::function<void(const std::shared_ptr<TraceFileEventObserver> &)> &f) const {
    decltype(observers_) copiedObservers;
    {
        std::lock_guard<std::mutex> l(observersLock_);
        copiedObservers = observers_;
    }
    for (const auto &weakPtr : copiedObservers) {
        if (auto sharedPtr = weakPtr.lock()) {
            f(sharedPtr);
        }
    }
}

} // namespace specto
