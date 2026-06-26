# App Hang V3 Profiling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture main-thread stack traces during app hangs and send them as profile chunks so the Sentry backend renders flamegraphs.

**Architecture:** When a hang is detected, the `SentryAppHangTracker` starts sampling the main thread's stack trace at a configurable interval (~100ms). Samples accumulate in a `SentryProfilerState` instance (the same deduplication engine the continuous profiler uses). When the hang ends, the accumulated data is serialized as a V2 `profile_chunk` envelope and sent. The hang event links to the profile via a `ProfileContext` in `event.contexts.profile`. If continuous profiling is already running, no custom sampling occurs — the event simply links to the existing profiler session ID.

**Tech Stack:** Swift, Objective-C++, `SentryProfilerState`, `SentryThreadInspector`, `SentryProfilerSerialization`, XCTest

## Global Constraints

- Platform gate: `#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)`
- Profiling gate: `#if SENTRY_TARGET_PROFILING_SUPPORTED`
- Profile chunk wire format version: `"2"` (V2 continuous profiling format)
- Envelope item type: `"profile_chunk"`
- Timestamps in samples: Unix seconds with microsecond precision (float64)
- Native frames require `instruction_addr` (hex string)
- `profiler_id` format: hex UUID v4, 32 chars, lowercase, no dashes
- Thread metadata key: string thread ID
- No force unwrapping (`!`) in Swift — use `guard let`, `if let`, or nil coalescing
- Follow existing dependency injection patterns (protocol-based `Dependencies` generic)
- Tests follow Arrange/Act/Assert pattern with `Invocations<T>` helper

---

### Task 1: Add profiling sample rate option to `AppHangsOptions`

Add an option to control the sampling rate for app hang profiling, mirroring Android's `anrProfilingSampleRate`.

**Files:**

- Modify: `Sources/Swift/SentryAppHangsOptions.swift`
- Test: `Tests/SentryTests/Integrations/AppHangs/SentryAppHangsOptionsTests.swift` (create if not exists)

**Interfaces:**

- Consumes: nothing
- Produces: `AppHangsOptions.profilingSampleRate: Double` (0.0–1.0, default 1.0), `AppHangsOptions.profilingSampleIntervalMs: Int` (default 100)

- [ ] **Step 1: Write tests for new options**

```swift
// Tests/SentryTests/Integrations/AppHangs/SentryAppHangsOptionsTests.swift
@testable import Sentry
import XCTest

final class SentryAppHangsOptionsTests: XCTestCase {

    func testProfilingSampleRate_defaultIsOne() {
        let sut = AppHangsOptions()
        XCTAssertEqual(sut.profilingSampleRate, 1.0)
    }

    func testProfilingSampleIntervalMs_defaultIs100() {
        let sut = AppHangsOptions()
        XCTAssertEqual(sut.profilingSampleIntervalMs, 100)
    }

    func testProfilingSampleRate_clampsToZero() {
        var sut = AppHangsOptions()
        sut.profilingSampleRate = -0.5
        XCTAssertEqual(sut.profilingSampleRate, 0.0)
    }

    func testProfilingSampleRate_clampsToOne() {
        var sut = AppHangsOptions()
        sut.profilingSampleRate = 1.5
        XCTAssertEqual(sut.profilingSampleRate, 1.0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test-macos ONLY_TESTING=SentryTests/SentryAppHangsOptionsTests 2>&1 | tail -20`
Expected: Compilation errors — properties don't exist yet.

- [ ] **Step 3: Add the new options**

```swift
// Sources/Swift/SentryAppHangsOptions.swift
public struct AppHangsOptions {

    public var enableV3 = false
    public var appHangThreshold: TimeInterval = 2.0

    /// Sample rate for profiling app hangs (0.0 to 1.0).
    /// When an app hang is detected, this rate determines whether
    /// stack trace sampling occurs for flamegraph generation.
    public var profilingSampleRate: Double {
        get { _profilingSampleRate }
        set { _profilingSampleRate = min(max(newValue, 0.0), 1.0) }
    }
    private var _profilingSampleRate: Double = 1.0

    /// Interval in milliseconds between main-thread stack trace samples
    /// during an app hang. Lower values give more detail but higher overhead.
    public var profilingSampleIntervalMs: Int = 100
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test-macos ONLY_TESTING=SentryTests/SentryAppHangsOptionsTests 2>&1 | tail -20`
Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Swift/SentryAppHangsOptions.swift Tests/SentryTests/Integrations/AppHangs/SentryAppHangsOptionsTests.swift
git commit -m "feat: add profiling options to AppHangsOptions"
```

---

### Task 2: Extend `SentryAppHang` with value-typed profiling data

The `SentryAppHang` struct needs to carry profiling data and timing information as pure value types (no reference semantics except `SentryId`). A nested `ProfilingData` struct with its own nested `Frame`, `Sample`, and `ThreadMetadata` structs holds the captured profile. Conversion to `NSDictionary` for serialization happens at the integration boundary (Task 4), not here.

**Files:**

- Modify: `Sources/Swift/Integrations/AppHangTracking/SentryAppHang.swift`

**Interfaces:**

- Consumes: nothing
- Produces: `SentryAppHang.profilerId: SentryId?`, `SentryAppHang.profilingData: SentryAppHang.ProfilingData?`, `SentryAppHang.startSystemTime: UInt64`, `SentryAppHang.endSystemTime: UInt64`, `SentryAppHang.ProfilingData` (with `.Frame`, `.Sample`, `.ThreadMetadata`)

- [ ] **Step 1: Extend the SentryAppHang struct**

```swift
// Sources/Swift/Integrations/AppHangTracking/SentryAppHang.swift
@_implementationOnly import _SentryPrivate

struct SentryAppHang {
    enum State {
        case started
        case ended
    }

    struct ProfilingData {
        struct Frame {
            let instructionAddress: String?
            let function: String?
            let module: String?
        }

        struct Sample {
            let absoluteTimestamp: UInt64
            let stackIndex: Int
            let threadId: UInt64
        }

        struct ThreadMetadata {
            let name: String
            let priority: Int
        }

        let frames: [Frame]
        let stacks: [[Int]]
        let samples: [Sample]
        let threadMetadata: [String: ThreadMetadata]
    }

    let duration: TimeInterval
    let state: State

    /// The profiler session ID for linking the hang event to its profile chunk.
    /// Set when continuous profiling is active or when custom sampling produced data.
    let profilerId: SentryId?

    /// Captured profile samples from custom main-thread sampling.
    /// nil when continuous profiling handled the data, or when profiling is disabled.
    let profilingData: ProfilingData?

    /// Mach absolute time when the hang started.
    let startSystemTime: UInt64

    /// Mach absolute time when the hang ended (or current time for .started state).
    let endSystemTime: UInt64
}
```

- [ ] **Step 2: Fix compilation — update all call sites creating SentryAppHang**

In `SentryAppHangTracker.swift`, the `processDelay` method creates `SentryAppHang` instances. Update to pass the new fields (with nil/0 defaults for now — Task 3 will wire up real values):

```swift
// In processDelay(), for .started:
entry.handler(.init(
    duration: delay.duration,
    state: .started,
    profilerId: nil,
    profilingData: nil,
    startSystemTime: 0,
    endSystemTime: 0
))

// In processDelay(), for .ended:
entry.handler(.init(
    duration: delay.duration,
    state: .ended,
    profilerId: nil,
    profilingData: nil,
    startSystemTime: 0,
    endSystemTime: 0
))
```

- [ ] **Step 3: Build to verify compilation**

Run: `make build-ios 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 4: Run existing tests to verify no regressions**

Run: `make test-macos ONLY_TESTING=SentryTests/SentryDefaultAppHangTrackerTests 2>&1 | tail -20`
Expected: All existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Swift/Integrations/AppHangTracking/SentryAppHang.swift Sources/Swift/Integrations/AppHangTracking/SentryAppHangTracker.swift
git commit -m "ref: extend SentryAppHang with profiling fields"
```

---

### Task 3: Add main-thread stack trace sampling to `SentryAppHangTracker`

This is the core change. When a hang starts and is sampled for profiling, the tracker begins capturing main-thread stack traces at the configured interval. When the hang ends, it packages the samples into `SentryAppHang.ProfilingData`.

There are two paths:

1. **Continuous profiler is running:** Just record the profiler ID and time range — no custom sampling.
2. **No profiler running:** Use `SentryThreadInspector` to sample the main thread and build `ProfilingData` from the captured stacks.

No dependency on `SentryProfilerState` or `SENTRY_TARGET_PROFILING_SUPPORTED` — this uses only `SentryThreadInspector` (available on all platforms) and builds the value-typed `ProfilingData` struct directly. The continuous profiler piggyback path is gated on `SENTRY_TARGET_PROFILING_SUPPORTED` since it references `SentryContinuousProfiler`.

**Files:**

- Modify: `Sources/Swift/Integrations/AppHangTracking/SentryAppHangTracker.swift`
- Modify: `Sources/Swift/SentryDependencyContainer.swift` (add `DateProviderProvider` to `SentryAppHangTrackerDependencies`)
- Test: `Tests/SentryTests/Integrations/AppHangs/SentryDefaultAppHangTrackerTests.swift`

**Interfaces:**

- Consumes: `SentryThreadInspector.getCurrentThreadsWithStackTrace()`, `SentryCurrentDateProvider.systemTime()`, `AppHangsOptions.profilingSampleRate`, `AppHangsOptions.profilingSampleIntervalMs`
- Produces: `SentryAppHang` with populated `profilerId`, `profilingData: ProfilingData?`, `startSystemTime`, `endSystemTime` fields

- [ ] **Step 1: Add DateProviderProvider to tracker dependencies**

In `SentryDependencyContainer.swift`, update the `SentryAppHangTrackerDependencies` typealias:

```swift
#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
typealias SentryAppHangTrackerDependencies = RunLoopDelayTrackerProvider & ThreadInspectorProvider & DateProviderProvider
#endif
```

The non-test path (production) uses `SentryDefaultAppHangTracker<SentryDependencyContainer>` which already conforms to all three protocols via extensions.

- [ ] **Step 2: Add a mutable sample accumulator**

Add a helper that accumulates samples during a hang, performing frame/stack deduplication. This is a mutable class used only internally during sampling — the final output is the immutable `ProfilingData` struct.

```swift
// In SentryAppHangTracker.swift, private to the file:

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
```

- [ ] **Step 3: Add profiling state to the tracker**

Add per-hang profiling state to `SentryDefaultAppHangTracker`. This tracks whether the current hang is being profiled, accumulates samples, and records timing.

```swift
// In SentryDefaultAppHangTracker, add to State section:

private struct HangProfilingContext {
    let profilerId: SentryId
    let startSystemTime: UInt64
    let accumulator: SampleAccumulator?
    let isUsingContinuousProfiler: Bool
    var sampleTimer: DispatchSourceTimer?
}

private var activeProfilingContext: HangProfilingContext?
private let dateProvider: SentryCurrentDateProvider
```

Update `init(dependencies:)` to capture the date provider:

```swift
init(dependencies: Dependencies) {
    self.runLoopDelayTracker = dependencies.runLoopDelayTracker
    self.threadInspector = dependencies.threadInspector
    self.dateProvider = dependencies.dateProvider
}
```

- [ ] **Step 4: Implement the sampling logic in processDelay**

Replace the `processDelay` method to start/stop profiling around hangs:

```swift
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
```

- [ ] **Step 5: Implement startProfilingIfNeeded()**

This method decides whether to piggyback on the continuous profiler or start custom sampling:

```swift
private func startProfilingIfNeeded() -> HangProfilingContext? {
    guard activeProfilingContext == nil else { return activeProfilingContext }

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
    let intervalMs = profilingSampleIntervalMs
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
```

- [ ] **Step 6: Implement stopProfilingIfNeeded()**

```swift
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
```

- [ ] **Step 7: Add profilingSampleIntervalMs property**

```swift
// In SentryDefaultAppHangTracker, add property:
var profilingSampleIntervalMs: Int = 100
```

- [ ] **Step 8: Remove buildFlamegraphFrames and FlameNode**

Delete the `FlameNode` class and `buildFlamegraphFrames` function from `SentryAppHangTracker.swift` — they produce the wrong format (tree with parentIndex/sampleCount) and are unused.

- [ ] **Step 9: Build to verify compilation**

Run: `make build-ios 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 10: Write tests for the custom sampling path**

```swift
// Add to SentryDefaultAppHangTrackerTests.swift

func testProcessDelay_whenHangEnds_profilingDataContainsSamples() throws {
    // -- Arrange --
    let delayTracker = MockSentryRunLoopDelayTracker()
    let sut = SentryDefaultAppHangTracker(dependencies: /* mock deps */)
    let callbacks = Invocations<SentryAppHang>()
    let startExpectation = expectation(description: "Hang started")
    let endExpectation = expectation(description: "Hang ended")

    var callCount = 0
    let token = sut.addObserver(threshold: 0.25) { hang in
        callbacks.record(hang)
        callCount += 1
        if callCount == 1 { startExpectation.fulfill() }
        if callCount == 2 { endExpectation.fulfill() }
    }
    defer { sut.removeObserver(token: token) }

    // -- Act --
    delayTracker.simulateDelay(duration: 0.3, ongoing: true)
    wait(for: [startExpectation], timeout: 1)

    // Let sampling timer fire a few times
    Thread.sleep(forTimeInterval: 0.3)

    delayTracker.simulateDelay(duration: 0.5, ongoing: false)
    wait(for: [endExpectation], timeout: 1)

    // -- Assert --
    let ended = try XCTUnwrap(callbacks.invocations.last)
    XCTAssertEqual(ended.state, .ended)
    XCTAssertNotNil(ended.profilerId)
    XCTAssertNotNil(ended.profilingData)

    let data = try XCTUnwrap(ended.profilingData)
    XCTAssertFalse(data.frames.isEmpty)
    XCTAssertFalse(data.stacks.isEmpty)
    XCTAssertFalse(data.samples.isEmpty)
    XCTAssertNotNil(data.threadMetadata["0"])
}

func testProcessDelay_whenHangEnds_profilingDataDeduplicatesFrames() throws {
    // -- Arrange --
    // Use a mock thread inspector that returns identical stacks each time
    let delayTracker = MockSentryRunLoopDelayTracker()
    let sut = SentryDefaultAppHangTracker(dependencies: /* mock deps with fixed stacks */)
    let callbacks = Invocations<SentryAppHang>()
    let endExpectation = expectation(description: "Hang ended")

    let token = sut.addObserver(threshold: 0.1) { hang in
        callbacks.record(hang)
        if hang.state == .ended { endExpectation.fulfill() }
    }
    defer { sut.removeObserver(token: token) }

    // -- Act --
    delayTracker.simulateDelay(duration: 0.2, ongoing: true)
    Thread.sleep(forTimeInterval: 0.3)
    delayTracker.simulateDelay(duration: 0.5, ongoing: false)
    wait(for: [endExpectation], timeout: 1)

    // -- Assert --
    let data = try XCTUnwrap(callbacks.invocations.last?.profilingData)
    // Multiple samples but only one unique stack (all identical)
    XCTAssertGreaterThan(data.samples.count, 1)
    XCTAssertEqual(data.stacks.count, 1)
}
```

Note: The exact test setup depends on how the Dependencies mock is structured. The mock `SentryThreadInspector` should return synthetic `SentryThread` objects with controlled stack traces.

- [ ] **Step 11: Run tests**

Run: `make test-macos ONLY_TESTING=SentryTests/SentryDefaultAppHangTrackerTests 2>&1 | tail -20`
Expected: All tests pass including the new ones.

- [ ] **Step 12: Commit**

```bash
git add Sources/Swift/Integrations/AppHangTracking/SentryAppHangTracker.swift Sources/Swift/SentryDependencyContainer.swift Tests/SentryTests/Integrations/AppHangs/SentryDefaultAppHangTrackerTests.swift
git commit -m "feat: sample main-thread stacks during app hangs"
```

---

### Task 4: Send profile chunk envelope and link to hang event

Wire up the V3 integration to convert `ProfilingData` into the V2 profile chunk wire format, send it as an envelope, and set `ProfileContext` on the hang event.

The conversion from value-typed `ProfilingData` to `NSDictionary` happens here at the serialization boundary — the data model stays clean.

**Files:**

- Modify: `Sources/Swift/Integrations/AppHangTracking/SentryHangTrackingV3Integration.swift`
- Test: `Tests/SentryTests/Integrations/AppHangs/SentryHangTrackingV3IntegrationTests.swift` (create)

**Interfaces:**

- Consumes: `SentryAppHang.profilerId: SentryId?`, `SentryAppHang.profilingData: ProfilingData?`, `SentryAppHang.startSystemTime`, `SentryAppHang.endSystemTime`, `sentry_continuousProfileChunkEnvelope()`, `SentrySDKInternal.captureEnvelope()`
- Produces: Hang event with `event.context["profile"]["profiler_id"]` set, profile chunk envelope sent

- [ ] **Step 1: Add ProfilingData → NSDictionary conversion**

This is an extension on `SentryAppHang.ProfilingData` that converts the value-typed struct into the `NSDictionary` format expected by `sentry_continuousProfileChunkEnvelope()`. This conversion lives in the integration file since it's a serialization concern:

```swift
// In SentryHangTrackingV3Integration.swift

extension SentryAppHang.ProfilingData {
    func toDictionary() -> [String: Any] {
        let serializedFrames: [[String: Any]] = frames.map { frame in
            var dict: [String: Any] = [:]
            if let addr = frame.instructionAddress { dict["instruction_addr"] = addr }
            if let function = frame.function { dict["function"] = function }
            if let module = frame.module { dict["module"] = module }
            return dict
        }

        let serializedStacks: [[NSNumber]] = stacks.map { stack in
            stack.map { NSNumber(value: $0) }
        }

        let serializedSamples: [[String: Any]] = samples.map { sample in
            [
                "timestamp": NSNumber(value: Double(sample.absoluteTimestamp) / 1_000_000_000.0),
                "thread_id": "\(sample.threadId)",
                "stack_id": NSNumber(value: sample.stackIndex)
            ]
        }

        let serializedThreadMetadata: [String: [String: Any]] = threadMetadata.mapValues { meta in
            ["name": meta.name, "priority": NSNumber(value: meta.priority)]
        }

        return [
            "profile": [
                "frames": serializedFrames,
                "stacks": serializedStacks,
                "samples": serializedSamples,
                "thread_metadata": serializedThreadMetadata
            ]
        ]
    }
}
```

Note: `absoluteTimestamp` comes from `clock_gettime_nsec_np(CLOCK_UPTIME_RAW)` (nanoseconds). The V2 wire format expects Unix seconds with microsecond precision. The `sentry_serializedContinuousProfileChunk` function handles the absolute→relative conversion internally, so we pass the raw nanosecond values and let that function normalize them. If it does not handle this conversion (it expects `SentrySample` objects with `absoluteNSDateInterval`), then this conversion needs to use `Date().timeIntervalSince1970` instead — verify during implementation.

- [ ] **Step 2: Update the integration to handle profiling on .ended**

The integration should act on `.ended` (when we have the full profile data), not `.started`:

```swift
// Sources/Swift/Integrations/AppHangTracking/SentryHangTrackingV3Integration.swift
#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
@_implementationOnly import _SentryPrivate

protocol SentryHangTrackingV3IntegrationProtocol {}

typealias SentryHangTrackingV3IntegrationDependencies = AppHangTrackerProvider & ClientProvider & ThreadInspectorProvider & DebugImageProvider & HubProvider

final class SentryHangTrackingV3Integration<Dependencies: SentryHangTrackingV3IntegrationDependencies>: NSObject, SwiftIntegration, SentryHangTrackingV3IntegrationProtocol {

    private let appHangTracker: SentryAppHangTracker
    private let observer: SentryAppHangTrackerObserverToken

    init?(with options: Options, dependencies: Dependencies) {
        guard options.experimental.appHangs.enableV3 else {
            return nil
        }

        self.appHangTracker = dependencies.appHangTracker
        observer = appHangTracker.addObserver(threshold: options.experimental.appHangs.appHangThreshold) { hang in
            guard hang.state == .ended else { return }
            guard let client = dependencies.client else {
                SentrySDKLog.debug("SentryHangTrackingV3Integration: No client available")
                return
            }

            // Build hang event
            let thread = SentryThread(threadId: NSNumber(value: 0))
            thread.name = "main"
            thread.crashed = NSNumber(value: false)
            thread.current = NSNumber(value: true)
            thread.isMain = NSNumber(value: true)

            let mechanism = Mechanism(type: "mx_hang_diagnostic")
            mechanism.handled = NSNumber(value: true)
            mechanism.synthetic = NSNumber(value: true)

            let exception = Exception(
                value: "App hang detected: \(String(format: "%.1f", hang.duration)) sec",
                type: "MXHangDiagnostic"
            )
            exception.mechanism = mechanism
            exception.threadId = NSNumber(value: 0)

            let event = Event(level: .warning)
            event.threads = [thread]
            event.exceptions = [exception]
            event.startSystemTime = hang.startSystemTime
            event.endSystemTime = hang.endSystemTime

            // Send profile chunk and link to event
            if let profilerId = hang.profilerId {
                Self.attachProfile(
                    to: event,
                    profilerId: profilerId,
                    profilingData: hang.profilingData
                )
            }

            client.capture(event: event)
        }

        super.init()
    }

    private static func attachProfile(
        to event: Event,
        profilerId: SentryId,
        profilingData: SentryAppHang.ProfilingData?
    ) {
        // Set profile context on event so backend links them
        var contexts = event.context ?? [:]
        contexts["profile"] = ["profiler_id": profilerId.sentryIdString]
        event.context = contexts

        // If we have custom profiling data (not from continuous profiler),
        // send it as a profile_chunk envelope
        guard let profilingData else { return }

        let profileDict = profilingData.toDictionary() as NSDictionary

        #if SENTRY_TARGET_PROFILING_SUPPORTED
        let envelope = sentry_continuousProfileChunkEnvelope(
            profilerId,
            profileDict,
            [:] // no metric profiler data for hang profiles
        )

        guard let envelope else {
            SentrySDKLog.debug("Failed to create profile chunk envelope")
            return
        }

        SentrySDKInternal.captureEnvelope(envelope)
        #endif
    }

    func uninstall() {}

    static var name: String {
        "SentryHangTrackingV3Integration"
    }
}
#endif
```

Note: `sentry_continuousProfileChunkEnvelope` is gated on `SENTRY_TARGET_PROFILING_SUPPORTED` because it lives in the profiling module. The `ProfileContext` is set unconditionally — even if the envelope can't be sent on unsupported platforms, the context is still useful for linking to continuous profiler data.

- [ ] **Step 3: Build to verify compilation**

Run: `make build-ios 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 4: Write tests for the integration**

```swift
// Tests/SentryTests/Integrations/AppHangs/SentryHangTrackingV3IntegrationTests.swift
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryHangTrackingV3IntegrationTests: XCTestCase {

    func testHangEnded_capturesEventWithProfileContext() throws {
        // -- Arrange --
        // Create mock dependencies that provide a controllable app hang tracker
        // and a spy client that captures the event
        // Simulate a hang with ProfilingData containing one sample

        // -- Act --
        // Trigger hang .ended callback with profilerId + profilingData

        // -- Assert --
        let event = try XCTUnwrap(spyClient.capturedEvents.last)
        let profileContext = try XCTUnwrap(event.context?["profile"] as? [String: Any])
        XCTAssertNotNil(profileContext["profiler_id"])
        XCTAssertEqual(event.level, .warning)
        XCTAssertEqual(event.exceptions?.first?.type, "MXHangDiagnostic")
    }

    func testHangStarted_doesNotCaptureEvent() {
        // -- Arrange / Act --
        // Trigger hang .started callback

        // -- Assert --
        XCTAssertTrue(spyClient.capturedEvents.isEmpty)
    }

    func testHangEnded_withoutProfilerId_capturesEventWithoutProfileContext() throws {
        // -- Arrange / Act --
        // Trigger hang .ended callback with profilerId = nil

        // -- Assert --
        let event = try XCTUnwrap(spyClient.capturedEvents.last)
        XCTAssertNil(event.context?["profile"])
    }

    func testProfilingData_toDictionary_serializesCorrectly() throws {
        let data = SentryAppHang.ProfilingData(
            frames: [.init(instructionAddress: "0x1234", function: "main", module: "App")],
            stacks: [[0]],
            samples: [.init(absoluteTimestamp: 1_000_000_000, stackIndex: 0, threadId: 259)],
            threadMetadata: ["259": .init(name: "main", priority: 0)]
        )
        let dict = data.toDictionary()
        let profile = try XCTUnwrap(dict["profile"] as? [String: Any])
        let frames = try XCTUnwrap(profile["frames"] as? [[String: Any]])
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0]["instruction_addr"] as? String, "0x1234")
        XCTAssertEqual(frames[0]["function"] as? String, "main")

        let samples = try XCTUnwrap(profile["samples"] as? [[String: Any]])
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0]["thread_id"] as? String, "259")

        let stacks = try XCTUnwrap(profile["stacks"] as? [[NSNumber]])
        XCTAssertEqual(stacks, [[NSNumber(value: 0)]])
    }
}
```

Note: Full test implementations depend on the mock infrastructure available in the test target. Use existing patterns from `SentryHangTrackingIntegrationTests.swift` as reference for mock setup.

- [ ] **Step 5: Run tests**

Run: `make test-macos ONLY_TESTING=SentryTests/SentryHangTrackingV3IntegrationTests 2>&1 | tail -20`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Swift/Integrations/AppHangTracking/SentryHangTrackingV3Integration.swift Tests/SentryTests/Integrations/AppHangs/SentryHangTrackingV3IntegrationTests.swift
git commit -m "feat: send profile chunk for app hang events"
```

---

### Task 5: Wire profiling options from integration to tracker

Pass the profiling configuration from the integration layer down to the tracker so the sample rate and interval are respected.

**Files:**

- Modify: `Sources/Swift/Integrations/AppHangTracking/SentryHangTrackingV3Integration.swift`
- Modify: `Sources/Swift/Integrations/AppHangTracking/SentryAppHangTracker.swift`

**Interfaces:**

- Consumes: `AppHangsOptions.profilingSampleRate`, `AppHangsOptions.profilingSampleIntervalMs`
- Produces: `SentryDefaultAppHangTracker.profilingSampleRate`, `SentryDefaultAppHangTracker.profilingSampleIntervalMs` configured from options

- [ ] **Step 1: Add profilingSampleRate to tracker**

```swift
// In SentryDefaultAppHangTracker, add property:
var profilingSampleRate: Double = 1.0
```

- [ ] **Step 2: Add sampling decision to startProfilingIfNeeded()**

At the top of `startProfilingIfNeeded()`, add:

```swift
guard Double.random(in: 0.0...1.0) < profilingSampleRate else {
    return nil
}
```

- [ ] **Step 3: Set options in integration init**

In `SentryHangTrackingV3Integration.init`, after getting the tracker, configure it:

```swift
if let tracker = appHangTracker as? SentryDefaultAppHangTracker<Dependencies> {
    tracker.profilingSampleRate = options.experimental.appHangs.profilingSampleRate
    tracker.profilingSampleIntervalMs = options.experimental.appHangs.profilingSampleIntervalMs
}
```

Note: This step depends on whether the tracker exposes these properties through the protocol. If the `SentryAppHangTracker` protocol doesn't expose them, they can be set via the concrete type directly.

- [ ] **Step 4: Build and test**

Run: `make build-ios 2>&1 | tail -20 && make test-macos ONLY_TESTING=SentryTests/SentryDefaultAppHangTrackerTests 2>&1 | tail -20`
Expected: Build and tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Swift/Integrations/AppHangTracking/SentryAppHangTracker.swift Sources/Swift/Integrations/AppHangTracking/SentryHangTrackingV3Integration.swift
git commit -m "feat: wire profiling options to app hang tracker"
```

---

### Task 6: Regenerate public API and verify

Since Task 1 added public properties to `AppHangsOptions`, the public API surface changed.

**Files:**

- Regenerate: `sdk_api.json`

- [ ] **Step 1: Regenerate public API**

Run: `make generate-public-api`

- [ ] **Step 2: Verify the diff**

Run: `git diff sdk_api.json`
Expected: New entries for `profilingSampleRate` and `profilingSampleIntervalMs` in `AppHangsOptions`.

- [ ] **Step 3: Full build check**

Run: `make build-ios 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 4: Run format and lint**

Run: `make format && make analyze 2>&1 | tail -20`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add sdk_api.json
git commit -m "build: regenerate public API for app hang profiling options"
```

---

## Architecture Notes

### Wire Format (V2 Profile Chunk)

The profile chunk envelope sent for app hangs follows the exact same format as continuous profiling chunks:

```json
{
  "version": "2",
  "profiler_id": "<hex-uuid-no-dashes>",
  "chunk_id": "<hex-uuid-no-dashes>",
  "platform": "cocoa",
  "release": "...",
  "client_sdk": {"name": "sentry.cocoa", "version": "..."},
  "environment": "...",
  "debug_meta": {"images": [...]},
  "profile": {
    "samples": [
      {"thread_id": "259", "stack_id": 0, "timestamp": 1724777211.503}
    ],
    "stacks": [[0, 3, 7]],
    "frames": [
      {"instruction_addr": "0x...", "function": "..."}
    ],
    "thread_metadata": {
      "259": {"name": "main"}
    }
  }
}
```

### Event → Profile Linking

The hang event links to its profile via:

```json
{
  "contexts": {
    "profile": {
      "profiler_id": "<same-id-as-chunk>"
    }
  }
}
```

### Two Profiling Paths

```
Hang detected
  ├─ SentryContinuousProfiler.isCurrentlyProfiling == true
  │   → Record existing profiler_id + time range
  │   → Set ProfileContext on event (backend slices existing chunks)
  │   → No custom sampling, no extra envelope
  │
  └─ Continuous profiler NOT running
      → Create SampleAccumulator (value-typed output)
      → Sample main thread every ~100ms via DispatchSource timer
      → On hang end: convert ProfilingData → NSDictionary → profile_chunk envelope
      → Set ProfileContext on event with matching profiler_id
```

### Data Flow

```
SentryThreadInspector.getCurrentThreadsWithStackTrace()
  → [SentryThread] (filter main)
    → SampleAccumulator.appendSample()
      → SentryAppHang.ProfilingData  (value types: Frame, Sample, ThreadMetadata)
        → ProfilingData.toDictionary()  (at serialization boundary)
          → sentry_continuousProfileChunkEnvelope()
            → SentryEnvelope (profile_chunk)
```

### SENTRY_TARGET_PROFILING_SUPPORTED Gates

The custom sampling itself does NOT require `SENTRY_TARGET_PROFILING_SUPPORTED` — it uses
only `SentryThreadInspector` and value-typed Swift structs. The gate is only needed for:

1. Checking `SentryContinuousProfiler.isCurrentlyProfiling` (piggyback path)
2. Calling `sentry_continuousProfileChunkEnvelope()` (serialization function lives in profiling module)

If profiling is not supported on the platform, sampling still works but the data cannot be
serialized into a chunk envelope. The `ProfileContext` is always set on the event regardless.

### Comparison with Android

| Aspect            | Android                                 | iOS (this plan)                                                            |
| ----------------- | --------------------------------------- | -------------------------------------------------------------------------- |
| Sampling method   | `Thread.getStackTrace()`                | `SentryThreadInspector.getCurrentThreadsWithStackTrace()` filtered to main |
| Sampling interval | 66ms                                    | Configurable, default 100ms                                                |
| Scope             | Main thread only                        | Main thread only                                                           |
| Storage           | Disk-persisted `QueueFile`              | In-memory `SampleAccumulator` → value-typed `ProfilingData`                |
| Serialization     | Custom `StackTraceConverter`            | `ProfilingData.toDictionary()` → `sentry_continuousProfileChunkEnvelope()` |
| Profile format    | `SentryProfile` (frames/stacks/samples) | Same V2 profile chunk format                                               |
| Linking           | `ProfileContext` on event               | `ProfileContext` on event                                                  |
| Sample rate       | `anrProfilingSampleRate`                | `profilingSampleRate`                                                      |
