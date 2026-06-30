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

typealias SentryAppHangTrackerDependencies = RunLoopDelayTrackerProvider & ThreadInspectorProvider & DateProviderProvider
#else
typealias SentryAppHangTrackerDependencies = RunLoopDelayTrackerProvider & ThreadInspectorProvider & DateProviderProvider
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
        let accumulator: SampleAccumulator?
        let isUsingContinuousProfiler: Bool
        var sampleTimer: DispatchSourceTimer?
    }

    // MARK: - State

    private let runLoopDelayTracker: SentryRunLoopDelayTracker
    private var runLoopDelayTrackerObserverToken: SentryRunLoopDelayTrackerObserverToken?

    private let threadInspector: SentryThreadInspector
    private let dateProvider: SentryCurrentDateProvider

    private let observers = SentryMutex<[UUID: ObserverEntry]>([:])
    private var activeProfilingContext: HangProfilingContext?

    // MARK: - Configuration

    let profilingOptions: Options

    // MARK: - Implementation

    init(dependencies: Dependencies, profilingOptions: Options = Options()) {
        self.runLoopDelayTracker = dependencies.runLoopDelayTracker
        self.threadInspector = dependencies.threadInspector
        self.dateProvider = dependencies.dateProvider
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

    private func processDelay(delay: SentryRunLoopDelay) {
        let notifications: [(SentryAppHangTrackerHandler, SentryAppHang)] = observers.withLock { entries in
            var result: [(SentryAppHangTrackerHandler, SentryAppHang)] = []

            if delay.isOngoing {
                let anyNeedsStart = entries.contains { _, entry in
                    delay.duration > entry.threshold && !entry.hasBeenNotified
                }
                let context: HangProfilingContext? = anyNeedsStart ? startProfilingIfNeeded() : nil
                if anyNeedsStart {
                    SentrySDKLog.debug("AppHangTracker: Profiling context: profilerId=\(context?.profilerId.sentryIdString ?? "nil"), isUsingContinuousProfiler=\(context?.isUsingContinuousProfiler.description ?? "nil")")
                }

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
            } else {
                let anyNeedsEnd = entries.values.contains { $0.hasBeenNotified }
                let endTime = dateProvider.systemTime()
                let profilingResult = anyNeedsEnd ? stopProfilingIfNeeded() : (profilerId: nil as SentryId?, profilingData: nil as SentryAppHang.ProfilingData?, startSystemTime: UInt64(0))
                if anyNeedsEnd {
                    SentrySDKLog.debug("AppHangTracker: Hang ended (duration=\(delay.duration)s), profilerId=\(profilingResult.profilerId?.sentryIdString ?? "nil"), hasSamples=\(profilingResult.profilingData != nil), sampleCount=\(profilingResult.profilingData?.samples.count ?? 0)")
                }

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
            }

            return result
        }
        for (handler, hang) in notifications {
            handler(hang)
        }
    }

    private func startProfilingIfNeeded() -> HangProfilingContext? {
        guard activeProfilingContext == nil else {
            SentrySDKLog.debug("AppHangTracker: startProfilingIfNeeded — already active, reusing existing context")
            return activeProfilingContext
        }

        let startTime = dateProvider.systemTime()

#if SENTRY_TARGET_PROFILING_SUPPORTED
        if SentryContinuousProfiler.isCurrentlyProfiling,
           let existingId = SentryContinuousProfiler.currentProfilerID {
            SentrySDKLog.debug("AppHangTracker: Piggyback on continuous profiler (profilerId=\(existingId.sentryIdString))")
            let context = HangProfilingContext(
                profilerId: existingId,
                startSystemTime: startTime,
                accumulator: nil,
                isUsingContinuousProfiler: true
            )
            activeProfilingContext = context
            return context
        }
#endif

        let accumulator = SampleAccumulator()
        let profilerId = SentryId()
        SentrySDKLog.debug("AppHangTracker: Starting custom sampling (profilerId=\(profilerId.sentryIdString), intervalMs=\(profilingOptions.sampleIntervalMs))")
        var context = HangProfilingContext(
            profilerId: profilerId,
            startSystemTime: startTime,
            accumulator: accumulator,
            isUsingContinuousProfiler: false
        )

        let threads = threadInspector.getCurrentThreadsWithStackTrace()
        accumulator.appendSample(from: threads, timestamp: dateProvider.date().timeIntervalSince1970)
        SentrySDKLog.debug("AppHangTracker: Took initial sample, \(threads.count) threads")

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        let intervalMs = profilingOptions.sampleIntervalMs
        timer.schedule(deadline: .now() + .milliseconds(intervalMs), repeating: .milliseconds(intervalMs))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let threads = self.threadInspector.getCurrentThreadsWithStackTrace()
            accumulator.appendSample(from: threads, timestamp: self.dateProvider.date().timeIntervalSince1970)
        }
        timer.resume()
        context.sampleTimer = timer

        activeProfilingContext = context
        return context
    }

    private func stopProfilingIfNeeded() -> (profilerId: SentryId?, profilingData: SentryAppHang.ProfilingData?, startSystemTime: UInt64) {
        guard let context = activeProfilingContext else {
            SentrySDKLog.debug("AppHangTracker: stopProfilingIfNeeded — no active context")
            return (nil, nil, 0)
        }
        activeProfilingContext = nil

        context.sampleTimer?.cancel()

        if context.isUsingContinuousProfiler {
            SentrySDKLog.debug("AppHangTracker: Stopped profiling (continuous profiler path, profilerId=\(context.profilerId.sentryIdString))")
            return (context.profilerId, nil, context.startSystemTime)
        }

        let profilingData = context.accumulator?.toProfilingData()
        SentrySDKLog.debug("AppHangTracker: Stopped profiling (custom sampling, profilerId=\(context.profilerId.sentryIdString), frames=\(profilingData?.frames.count ?? 0), stacks=\(profilingData?.stacks.count ?? 0), samples=\(profilingData?.samples.count ?? 0))")
        return (context.profilerId, profilingData, context.startSystemTime)
    }
}

// MARK: - SampleAccumulator

final class SampleAccumulator {
    private struct FrameKey: Hashable {
        let instructionAddress: String?
        let function: String?
        let module: String?
    }

    private var frameIndex: [FrameKey: Int] = [:]
    private var frames: [SentryAppHang.ProfilingData.Frame] = []
    private var stackIndex: [[Int]: Int] = [:]
    private var stacks: [[Int]] = []
    private var samples: [SentryAppHang.ProfilingData.Sample] = []
    private var threadMetadata: [String: SentryAppHang.ProfilingData.ThreadMetadata] = [:]

    func appendSample(from threads: [SentryThread], timestamp: TimeInterval) {
        for thread in threads {
            let threadId = thread.threadId?.uint64Value ?? 0
            let threadIdStr = "\(threadId)"

            if threadMetadata[threadIdStr] == nil {
                threadMetadata[threadIdStr] = .init(
                    name: thread.name ?? "Thread \(threadId)",
                    priority: 0
                )
            }

            var frameIndices: [Int] = []
            if let stacktrace = thread.stacktrace {
                for frame in stacktrace.frames {
                    let key = FrameKey(
                        instructionAddress: frame.instructionAddress,
                        function: frame.function,
                        module: frame.module
                    )
                    let idx: Int
                    if let existing = frameIndex[key] {
                        idx = existing
                    } else {
                        idx = frames.count
                        frameIndex[key] = idx
                        frames.append(.init(
                            instructionAddress: frame.instructionAddress,
                            function: frame.function,
                            module: frame.module
                        ))
                    }
                    frameIndices.append(idx)
                }
            }

            let stackIdx: Int
            if let existing = stackIndex[frameIndices] {
                stackIdx = existing
            } else {
                stackIdx = stacks.count
                stackIndex[frameIndices] = stackIdx
                stacks.append(frameIndices)
            }

            samples.append(.init(
                timestamp: timestamp,
                stackIndex: stackIdx,
                threadId: threadId
            ))
        }
    }

    func toProfilingData() -> SentryAppHang.ProfilingData {
        SentryAppHang.ProfilingData(
            frames: frames,
            stacks: stacks,
            samples: samples,
            threadMetadata: threadMetadata
        )
    }
}
