// Copyright (c) Specto Inc. All rights reserved.

#include "TraceEventSubject.h"

#include <algorithm>

namespace specto {

void TraceEventSubject::addObserver(std::shared_ptr<TraceEventObserver> observer) {
    if (observer == nullptr) {
        return;
    }
    std::lock_guard<std::mutex> l(observersLock_);
    observers_.push_back(std::move(observer));
}

void TraceEventSubject::removeObserver(std::shared_ptr<TraceEventObserver> observer) {
    if (observer == nullptr) {
        return;
    }
    std::lock_guard<std::mutex> l(observersLock_);
    observers_.erase(std::remove_if(observers_.begin(), observers_.end(), [&](const auto &weakPtr) {
        return weakPtr.expired() || weakPtr.lock() == observer;
    }));
}

void TraceEventSubject::traceStarted(TraceID traceID) {
    forEachObserver([traceID](const auto &observer) { observer->traceStarted(traceID); });
}

void TraceEventSubject::traceEnded(TraceID traceID) {
    forEachObserver([traceID](const auto &observer) { observer->traceEnded(traceID); });
}

void TraceEventSubject::traceFailed(TraceID traceID, const proto::Error &error) {
    forEachObserver(
      [traceID, &error](const auto &observer) { observer->traceFailed(traceID, error); });
}

TraceEventSubject::TraceEventSubject() = default;

void TraceEventSubject::forEachObserver(
  const std::function<void(const std::shared_ptr<TraceEventObserver> &)> &f) const {
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
