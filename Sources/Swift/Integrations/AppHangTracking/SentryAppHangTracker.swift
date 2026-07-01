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

typealias SentryAppHangTrackerDependencies = RunLoopDelayTrackerProvider & ThreadInspectorProvider & DateProviderProvider & DispatchFactoryProvider
#else
typealias SentryAppHangTrackerDependencies = RunLoopDelayTrackerProvider & ThreadInspectorProvider & DateProviderProvider & DispatchFactoryProvider
typealias SentryAppHangTracker = SentryDefaultAppHangTracker<SentryDependencyContainer>
#endif

/// Debounces raw runloop delays into hang events with per-observer thresholds.
///
/// Wraps a `SentryRunLoopDelayTracker` (which polls at ~25ms) and notifies each observer
/// only when the accumulated delay exceeds that observer's configured threshold.
/// Each observer receives at most one `.started` notification per hang,
/// followed by one `.ended` when the hang resolves.
final class SentryDefaultAppHangTracker<Dependencies: SentryAppHangTrackerDependencies> {
    // MARK: - Types

    struct Options {
        let sampleIntervalMs: Int

        init(sampleIntervalMs: Int = 100) {
            self.sampleIntervalMs = sampleIntervalMs
        }
    }

    private struct ObserverEntry {
        let threshold: TimeInterval
        let handler: SentryAppHangTrackerHandler
        var hasBeenNotified: Bool = false
    }

    private struct HangProfilingContext {
        let profilerId: SentryId
        let startSystemTime: UInt64
        let isUsingContinuousProfiler: Bool
        var sampleTimer: SentryDispatchSourceWrapper?
    }

    // MARK: - State

    private let runLoopDelayTracker: SentryRunLoopDelayTracker
    private var runLoopDelayTrackerObserverToken: SentryRunLoopDelayTrackerObserverToken?

    private let threadInspector: SentryThreadInspector
    private let dateProvider: SentryCurrentDateProvider
    private let dispatchFactory: SentryDispatchFactory

    private let observers = SentryMutex<[UUID: ObserverEntry]>([:])
    private var activeProfilingContext: HangProfilingContext?
    private var accumulator = SentryProfilingSampleAccumulator()

    // MARK: - Configuration

    let profilingOptions: Options

    // MARK: - Implementation

    init(dependencies: Dependencies, profilingOptions: Options = Options()) {
        self.runLoopDelayTracker = dependencies.runLoopDelayTracker
        self.threadInspector = dependencies.threadInspector
        self.dateProvider = dependencies.dateProvider
        self.dispatchFactory = dependencies.dispatchFactory
        self.profilingOptions = profilingOptions
        SentrySDKLog.debug("AppHangTracker: Initialized (sampleIntervalMs=\(profilingOptions.sampleIntervalMs))")
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
        let (_, isEmpty) = observers.withLock {
            ($0.removeValue(forKey: token), $0.isEmpty)
        }

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

    // MARK: - Delay Processing

    private func processDelay(delay: SentryRunLoopDelay) {
        // Collect notifications under the lock but invoke handlers outside the critical section
        // to avoid deadlocks if a handler calls addObserver/removeObserver.
        let notifications: [(SentryAppHangTrackerHandler, SentryAppHang)] = observers.withLock { entries in
            if delay.isOngoing {
                return processOngoingDelay(delay: delay, entries: &entries)
            } else {
                return processEndedDelay(delay: delay, entries: &entries)
            }
        }
        for (handler, hang) in notifications {
            handler(hang)
        }
    }

    private func processOngoingDelay(
        delay: SentryRunLoopDelay,
        entries: inout [UUID: ObserverEntry]
    ) -> [(SentryAppHangTrackerHandler, SentryAppHang)] {
        // Start profiling on the first ongoing delay, before any threshold is crossed.
        // If the delay resolves before a threshold, the data is discarded in processEndedDelay.
        let context = startProfilingIfNeeded()

        var result: [(SentryAppHangTrackerHandler, SentryAppHang)] = []

        for (token, entry) in entries {
            if delay.duration > entry.threshold && !entry.hasBeenNotified {
                entries[token]?.hasBeenNotified = true
                SentrySDKLog.debug("AppHangTracker: Hang started (duration=\(delay.duration)s, threshold=\(entry.threshold)s)")
                result.append((entry.handler, .init(
                    duration: delay.duration,
                    state: .started,
                    profilerId: context?.profilerId,
                    profilingData: nil,
                    startSystemTime: context?.startSystemTime ?? 0,
                    endSystemTime: dateProvider.systemTime()
                )))
            }
        }

        return result
    }

    private func processEndedDelay(
        delay: SentryRunLoopDelay,
        entries: inout [UUID: ObserverEntry]
    ) -> [(SentryAppHangTrackerHandler, SentryAppHang)] {
        let anyNeedsEnd = entries.values.contains { $0.hasBeenNotified }

        // Always stop profiling — it may have started before any threshold was crossed.
        // If no observer was notified, the profiling data is discarded.
        let endTime = dateProvider.systemTime()
        let profilingResult = stopProfilingIfNeeded()

        guard anyNeedsEnd else { return [] }

        SentrySDKLog.debug("AppHangTracker: Hang ended (duration=\(delay.duration)s), profilerId=\(profilingResult.profilerId?.sentryIdString ?? "nil"), sampleCount=\(profilingResult.profilingData?.samples.count ?? 0)")

        var result: [(SentryAppHangTrackerHandler, SentryAppHang)] = []

        for (token, entry) in entries {
            if entry.hasBeenNotified {
                entries[token]?.hasBeenNotified = false
                result.append((entry.handler, .init(
                    duration: delay.duration,
                    state: .ended,
                    profilerId: profilingResult.profilerId,
                    profilingData: profilingResult.profilingData,
                    startSystemTime: profilingResult.startSystemTime,
                    endSystemTime: endTime
                )))
            }
        }

        return result
    }

    // MARK: - Profiling

    private func startProfilingIfNeeded() -> HangProfilingContext? {
        guard activeProfilingContext == nil else {
            return activeProfilingContext
        }

        let startTime = dateProvider.systemTime()

#if SENTRY_TARGET_PROFILING_SUPPORTED
        if SentryContinuousProfiler.isCurrentlyProfiling,
           let existingId = SentryContinuousProfiler.currentProfilerID {
            SentrySDKLog.debug("AppHangTracker: Using existing continuous profiler (profilerId=\(existingId.sentryIdString))")
            let context = HangProfilingContext(
                profilerId: existingId,
                startSystemTime: startTime,
                isUsingContinuousProfiler: true
            )
            activeProfilingContext = context
            return context
        }
#endif

        accumulator = SentryProfilingSampleAccumulator()
        let profilerId = SentryId()
        let intervalNs = profilingOptions.sampleIntervalMs * 1_000_000

        SentrySDKLog.debug("AppHangTracker: Starting custom sampling (profilerId=\(profilerId.sentryIdString), intervalMs=\(profilingOptions.sampleIntervalMs))")

        var context = HangProfilingContext(
            profilerId: profilerId,
            startSystemTime: startTime,
            isUsingContinuousProfiler: false
        )
        context.sampleTimer = SentryDispatchSourceWrapper(
            interval: intervalNs,
            leeway: intervalNs / 10,
            queue: dispatchFactory.createHighPriorityQueue("io.sentry.app-hang-profiling"),
            eventHandler: { [weak self] in
                guard let self else { return }
                let threads = self.threadInspector.getCurrentThreadsWithStackTrace()
                self.accumulator.appendSample(from: threads, timestamp: self.dateProvider.date().timeIntervalSince1970)
            }
        )

        activeProfilingContext = context
        return context
    }

    private func stopProfilingIfNeeded() -> (profilerId: SentryId?, profilingData: SentryAppHang.ProfilingData?, startSystemTime: UInt64) {
        guard let context = activeProfilingContext else {
            return (nil, nil, 0)
        }
        activeProfilingContext = nil
        context.sampleTimer?.cancel()

        if context.isUsingContinuousProfiler {
            return (context.profilerId, nil, context.startSystemTime)
        }

        let profilingData = accumulator.toProfilingData()
        SentrySDKLog.debug("AppHangTracker: Stopped profiling (profilerId=\(context.profilerId.sentryIdString), frames=\(profilingData.frames.count), stacks=\(profilingData.stacks.count), samples=\(profilingData.samples.count))")
        return (context.profilerId, profilingData, context.startSystemTime)
    }
}
