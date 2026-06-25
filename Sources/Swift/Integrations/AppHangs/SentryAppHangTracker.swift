@_implementationOnly import _SentryPrivate

struct SentryAppHang {
    enum State {
        case started
        case ended
    }

    let duration: TimeInterval
    let state: State
}
typealias SentryAppHangTrackerHandler = (_ hang: SentryAppHang) -> Void
typealias SentryAppHangTrackerObserverToken = UUID
#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryAppHangTracker {
    func addObserver(threshold: TimeInterval, handler: @escaping SentryAppHangTrackerHandler) -> SentryAppHangTrackerObserverToken
    func removeObserver(token: SentryAppHangTrackerObserverToken)
}

extension SentryDefaultAppHangTracker: SentryAppHangTracker { }
#else
typealias SentryAppHangTracker = SentryDefaultAppHangTracker
#endif

/// Debounces raw runloop delays into hang events with per-observer thresholds.
///
/// Wraps a `SentryRunLoopDelayTracker` (which polls at ~25ms) and notifies each observer
/// only when the accumulated delay exceeds that observer's configured threshold.
/// Each observer receives at most one `ongoing=true` notification per hang,
/// followed by one `ongoing=false` when the hang ends.
final class SentryDefaultAppHangTracker {
    // MARK: - Types

    private struct ObserverEntry {
        let threshold: TimeInterval
        let handler: SentryAppHangTrackerHandler
        var hasBeenNotified: Bool = false
    }

    // MARK: - State

    private let runLoopDelayTracker: SentryRunLoopDelayTracker
    private var runLoopDelayTrackerObserverToken: SentryRunLoopDelayTrackerObserverToken?

    private let observersLock = NSRecursiveLock()
    private var observers = [UUID: ObserverEntry]()

    // MARK: - Implementation

    init(runLoopDelayTracker: SentryRunLoopDelayTracker) {
        self.runLoopDelayTracker = runLoopDelayTracker
    }

    /// Adds an observer for app hangs, notified if an app hang is longer than the given threshold
    ///
    /// Each observer is notified exactly once when the app hang started, and eventually once if the app hang ended if the app did not exit already
    ///
    /// - Parameter threshold: Minimum duration of the app hang defined in seconds
    /// - Parameter handler: Closure called with app hang information, from the **background thread**
    /// - Precondition: Must be called on main queue
    func addObserver(threshold: TimeInterval, handler: @escaping SentryAppHangTrackerHandler) -> SentryAppHangTrackerObserverToken {
        let token = SentryAppHangTrackerObserverToken()
        observersLock.synchronized {
            observers[token] = ObserverEntry(threshold: threshold, handler: handler)
        }
        startIfNecessary()
        return token
    }

    /// Removes the observer with the given token
    ///
    /// - Precondition: Must be called on main queue
    func removeObserver(token: SentryAppHangTrackerObserverToken) {
        // Return the removed entry out of the lock so its closure is destroyed outside the critical region.
        let (removed, isEmpty) = observersLock.synchronized {
            (observers.removeValue(forKey: token), observers.isEmpty)
        }
        _ = removed

        if isEmpty {
            stopIfRunning()
        }
    }

    /// - Precondition: Must be called on main queue
    private func startIfNecessary() {
        guard runLoopDelayTrackerObserverToken == nil else { return }
        runLoopDelayTrackerObserverToken = runLoopDelayTracker.addObserver { [weak self] delay in
            self?.processDelay(delay: delay)
        }
    }

    /// - Precondition: Must be called on main queue
    private func stopIfRunning() {
        guard let token = runLoopDelayTrackerObserverToken else { return }
        runLoopDelayTracker.removeObserver(token: token)
        runLoopDelayTrackerObserverToken = nil
    }

    private func processDelay(delay: SentryRunLoopDelay) {
        observersLock.synchronized {
            for (token, entry) in observers {
                if delay.isOngoing {
                    if delay.duration > entry.threshold && !entry.hasBeenNotified {
                        observers[token]?.hasBeenNotified = true
                        entry.handler(.init(duration: delay.duration, state: .started))
                    }
                } else if entry.hasBeenNotified {
                    observers[token]?.hasBeenNotified = false
                    entry.handler(.init(duration: delay.duration, state: .ended))
                }
            }
        }
    }
}
