@_implementationOnly import _SentryPrivate

protocol HangTrackerProvider {
    var hangTracker: HangTracker { get }
}
extension SentryDependencyContainer: HangTrackerProvider { }

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol HangTracker {
    func addObserver(threshold: TimeInterval, handler: @escaping (_ duration: TimeInterval, _ ongoing: Bool) -> Void) -> UUID

    func removeObserver(id: UUID)
}

extension DefaultHangTracker: HangTracker { }
#else
typealias HangTracker = DefaultHangTracker
#endif

/// Debounces raw runloop delays into hang events with per-observer thresholds.
///
/// Wraps a `RunLoopDelayTracker` (which polls at ~25ms) and notifies each observer
/// only when the accumulated delay exceeds that observer's configured threshold.
/// Each observer receives at most one `ongoing=true` notification per hang,
/// followed by one `ongoing=false` when the hang ends.
final class DefaultHangTracker {

    init(runLoopDelayTracker: RunLoopDelayTracker) {
        self.runLoopDelayTracker = runLoopDelayTracker
    }

    func addObserver(threshold: TimeInterval, handler: @escaping (_ duration: TimeInterval, _ ongoing: Bool) -> Void) -> UUID {
        let id = UUID()
        observersLock.synchronized {
            observers[id] = ObserverEntry(threshold: threshold, handler: handler)
        }
        startIfNecessary()
        return id
    }

    func removeObserver(id: UUID) {
        observersLock.synchronized {
            _ = observers.removeValue(forKey: id)
        }
        if observers.isEmpty {
            stopIfRunning()
        }
    }

    private struct ObserverEntry {
        let threshold: TimeInterval
        let handler: (TimeInterval, Bool) -> Void
        var hasBeenNotified: Bool = false
    }

    private let runLoopDelayTracker: RunLoopDelayTracker
    private let observersLock = NSRecursiveLock()
    private var observers = [UUID: ObserverEntry]()
    private var delayTrackerObserverId: UUID?

    private func startIfNecessary() {
        guard delayTrackerObserverId == nil else { return }
        delayTrackerObserverId = runLoopDelayTracker.addObserver { [weak self] duration, ongoing in
            self?.processDelay(duration: duration, ongoing: ongoing)
        }
    }

    private func stopIfRunning() {
        guard let id = delayTrackerObserverId else { return }
        runLoopDelayTracker.removeObserver(id: id)
        delayTrackerObserverId = nil
    }

    private func processDelay(duration: TimeInterval, ongoing: Bool) {
        observersLock.synchronized {
            for (id, entry) in observers {
                if ongoing {
                    if duration > entry.threshold && !entry.hasBeenNotified {
                        observers[id]?.hasBeenNotified = true
                        entry.handler(duration, true)
                    }
                } else {
                    if entry.hasBeenNotified {
                        observers[id]?.hasBeenNotified = false
                        entry.handler(duration, false)
                    }
                }
            }
        }
    }
}
