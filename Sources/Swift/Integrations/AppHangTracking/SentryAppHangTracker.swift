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
        let sampleRate: Double
        let sampleIntervalMs: Int

        init(sampleRate: Double = 1.0, sampleIntervalMs: Int = 100) {
            self.sampleRate = min(max(sampleRate, 0.0), 1.0)
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

                        let context = startProfilingIfNeeded()
                        entry.handler(.init(
                            duration: delay.duration,
                            state: .started,
                            profilerId: context?.profilerId,
                            profilingData: nil,
                            startSystemTime: context?.startSystemTime ?? 0,
                            endSystemTime: dateProvider.systemTime()
                        ))
                    }
                } else if entry.hasBeenNotified {
                    entries[token]?.hasBeenNotified = false

                    let endTime = dateProvider.systemTime()
                    let result = stopProfilingIfNeeded()
                    print(result.profilerId as Any)
                    entry.handler(.init(
                        duration: delay.duration,
                        state: .ended,
                        profilerId: result.profilerId,
                        profilingData: result.profilingData,
                        startSystemTime: result.startSystemTime,
                        endSystemTime: endTime
                    ))
                }
            }
        }
    }

    private func startProfilingIfNeeded() -> HangProfilingContext? {
        guard activeProfilingContext == nil else { return activeProfilingContext }
        guard Double.random(in: 0.0...1.0) < profilingOptions.sampleRate else { return nil }

        let startTime = dateProvider.systemTime()

#if SENTRY_TARGET_PROFILING_SUPPORTED
        // Path 1: Continuous profiler is already capturing — just record its ID
        if SentryContinuousProfiler.isCurrentlyProfiling,
           let existingId = SentryContinuousProfiler.currentProfilerID {
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

        // Path 2: Start custom main-thread sampling
        let accumulator = SampleAccumulator()
        let profilerId = SentryId()
        var context = HangProfilingContext(
            profilerId: profilerId,
            startSystemTime: startTime,
            accumulator: accumulator,
            isUsingContinuousProfiler: false
        )

        // Take an immediate first sample
        let threads = threadInspector.getCurrentThreadsWithStackTrace()
        accumulator.appendSample(from: threads, timestamp: startTime)

        // Schedule recurring samples
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        let intervalMs = profilingOptions.sampleIntervalMs
        timer.schedule(deadline: .now() + .milliseconds(intervalMs), repeating: .milliseconds(intervalMs))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let threads = self.threadInspector.getCurrentThreadsWithStackTrace()
            accumulator.appendSample(from: threads, timestamp: self.dateProvider.systemTime())
        }
        timer.resume()
        context.sampleTimer = timer

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

        let profilingData = context.accumulator?.toProfilingData()
        return (context.profilerId, profilingData, context.startSystemTime)
    }
}

// MARK: - SampleAccumulator

private final class SampleAccumulator {
    private(set) var frames: [SentryAppHang.ProfilingData.Frame] = []
    private(set) var stacks: [[Int]] = []
    private(set) var samples: [SentryAppHang.ProfilingData.Sample] = []
    private(set) var threadMetadata: [String: SentryAppHang.ProfilingData.ThreadMetadata] = [:]

    private var frameIndexLookup: [String: Int] = [:]
    private var stackIndexLookup: [String: Int] = [:]

    func appendSample(from threads: [SentryThread], timestamp: UInt64) {
        guard let mainThread = threads.first(where: { $0.isMain?.boolValue == true }),
              let stacktrace = mainThread.stacktrace,
              !stacktrace.frames.isEmpty else {
            return
        }

        let threadId = mainThread.threadId?.uint64Value ?? 0

        var frameIndices: [Int] = []
        for frame in stacktrace.frames {
            let key = frame.instructionAddress ?? frame.function ?? "?"
            if let existingIndex = frameIndexLookup[key] {
                frameIndices.append(existingIndex)
            } else {
                let index = frames.count
                frames.append(.init(
                    instructionAddress: frame.instructionAddress,
                    function: frame.function,
                    module: frame.package
                ))
                frameIndexLookup[key] = index
                frameIndices.append(index)
            }
        }

        let stackKey = frameIndices.map(String.init).joined(separator: ",")
        let stackIndex: Int
        if let existingStackIndex = stackIndexLookup[stackKey] {
            stackIndex = existingStackIndex
        } else {
            stackIndex = stacks.count
            stacks.append(frameIndices)
            stackIndexLookup[stackKey] = stackIndex
        }

        samples.append(.init(
            absoluteTimestamp: timestamp,
            stackIndex: stackIndex,
            threadId: threadId
        ))

        let threadIdStr = "\(threadId)"
        if threadMetadata[threadIdStr] == nil {
            threadMetadata[threadIdStr] = .init(name: "main", priority: 0)
        }
    }

    func toProfilingData() -> SentryAppHang.ProfilingData? {
        guard !samples.isEmpty else { return nil }
        return .init(
            frames: frames,
            stacks: stacks,
            samples: samples,
            threadMetadata: threadMetadata
        )
    }
}
