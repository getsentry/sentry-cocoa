typealias SentryAppHangTrackerHandler = (_ hang: SentryAppHang) -> Void
typealias SentryAppHangTrackerObserverToken = UUID

// In test/debug builds we use a protocol so that the tracker can be replaced with a mock.
// In release builds the protocol indirection is eliminated via a typealias.
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
/// Each observer receives at most one `.started` notification per hang,
/// followed by one `.ended` when the hang resolves.
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

    private let observers = SentryMutex<[UUID: ObserverEntry]>([:])

    // MARK: - Implementation

    init(runLoopDelayTracker: SentryRunLoopDelayTracker) {
        self.runLoopDelayTracker = runLoopDelayTracker
    }

    /// Adds an observer for app hangs exceeding the given threshold.
    ///
    /// Each observer is notified exactly once with `.started` when the hang begins,
    /// and once with `.ended` when it resolves — unless the app exits first.
    ///
    /// - Parameter threshold: Minimum hang duration in seconds before the observer is notified.
    /// - Parameter handler: Called on a **background queue** with hang information.
    /// - Precondition: Must be called on main queue.
    func addObserver(threshold: TimeInterval, handler: @escaping SentryAppHangTrackerHandler) -> SentryAppHangTrackerObserverToken {
        let token = SentryAppHangTrackerObserverToken()
        observers.withLock {
            $0[token] = ObserverEntry(threshold: threshold, handler: handler)
        }
        startIfNecessary()
        return token
    }

    /// Removes the observer with the given token
    ///
    /// - Precondition: Must be called on main queue
    func removeObserver(token: SentryAppHangTrackerObserverToken) {
        // Return the removed entry out of the lock so its closure is destroyed outside the critical region.
        let (removed, isEmpty) = observers.withLock {
            ($0.removeValue(forKey: token), $0.isEmpty)
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
        observers.withLock { entries in
            for (token, entry) in entries {
                if delay.isOngoing {
                    if delay.duration > entry.threshold && !entry.hasBeenNotified {
                        entries[token]?.hasBeenNotified = true
                        entry.handler(.init(duration: delay.duration, state: .started))
                    }
                } else if entry.hasBeenNotified {
                    entries[token]?.hasBeenNotified = false
                    entry.handler(.init(duration: delay.duration, state: .ended))
                }
            }
        }
    }
}

private class FlameNode {
    let frame: Frame
    var sampleCount: Int = 0
    var childKeys: [String] = []
    var children: [String: FlameNode] = [:]

    init(frame: Frame) {
        self.frame = frame
    }
}

/// Merges multiple sampled stacktraces into a single flamegraph tree,
/// flattened into an array of frames with `parentIndex` and `sampleCount`.
private func buildFlamegraphFrames(from stacktraces: [SentryStacktrace]) -> [Frame] {
    let root = FlameNode(frame: Frame())

    for stacktrace in stacktraces {
        var current = root
        current.sampleCount += 1

        for frame in stacktrace.frames {
            let key = frame.instructionAddress ?? frame.function ?? "?"
            if let child = current.children[key] {
                child.sampleCount += 1
                current = child
            } else {
                let node = FlameNode(frame: frame)
                node.sampleCount = 1
                current.childKeys.append(key)
                current.children[key] = node
                current = node
            }
        }
    }

    var result: [Frame] = []

    func flatten(_ node: FlameNode, parentIndex: Int) {
        for key in node.childKeys {
            guard let child = node.children[key] else { continue }
            let idx = result.count
            child.frame.parentIndex = NSNumber(value: parentIndex)
            child.frame.sampleCount = NSNumber(value: child.sampleCount)
            result.append(child.frame)
            flatten(child, parentIndex: idx)
        }
    }

    flatten(root, parentIndex: -1)
    return result
}
