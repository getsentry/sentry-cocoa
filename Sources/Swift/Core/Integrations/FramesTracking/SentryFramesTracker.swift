// swiftlint:disable file_length type_body_length missing_docs
internal import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
private typealias CrossPlatformApplication = UIApplication
#elseif (os(macOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UI_FRAMEWORK
import AppKit
private typealias CrossPlatformApplication = NSApplication
#endif

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

@_spi(Private) @objc
public protocol SentryFramesTrackerListener: NSObjectProtocol {
    func framesTrackerHasNewFrame(_ newFrameDate: Date)
}

@_spi(Private) @objc
public class SentryFramesTracker: NSObject {

    private var isStarted: Bool = false

    // MARK: Private properties
    private let _isRunning = SentryMutex<Bool>(false)

    @objc public private(set) var isRunning: Bool {
        get {
            _isRunning.withLock { $0 }
        }
        set {
            _isRunning.withLock { $0 = newValue }
        }
    }
    private var currentFrameRate: UInt64 = 60
    // We hold listeners through `WeakReference` rather than `NSHashTable.weakObjects()`
    // because NSHashTable's internal buckets can be zeroed by the ObjC runtime on the
    // deallocating thread while the table is being iterated on another thread, causing
    // `NSConcreteHashTable removeItem:` to `objc_msgSend` a freed entry.
    // `WeakReference` is read via `objc_loadWeak`, which is safe against concurrent
    // deallocation.
    private var listeners: [WeakReference<SentryFramesTrackerListener>] = [] {
        didSet {
            // A listener waits for the next frame. Without continuous updates that frame never
            // comes while nothing on screen changes.
            frameSource.requiresContinuousFrames = !listeners.isEmpty
        }
    }

#if os(iOS)
    private var frozenFrameTimestamps = SentryFrameInfoTimeSeries()
    private var slowFrameTimestamps = SentryFrameInfoTimeSeries()
    private var frameRateTimestamps = SentryFrameInfoTimeSeries()
#endif // os(iOS)

    // Frame counters - accessed only from main thread (frame source callbacks)
    private var slowFrames: UInt = 0
    private var frozenFrames: UInt = 0

    /// How the frames are observed. A var only so that tests can replace it.
    private var frameSource: SentryFrameSource
    let dateProvider: SentryCurrentDateProvider
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let notificationCenter: SentryNSNotificationCenterWrapper
    private var delayedFramesTracker: SentryDelayedFramesTrackerWrapper
    
    private static let frozenFrameThreshold: CFTimeInterval = 0.7

    init(
        frameSource: SentryFrameSource,
        dateProvider: SentryCurrentDateProvider,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        notificationCenter: SentryNSNotificationCenterWrapper,
        delayedFramesTracker: SentryDelayedFramesTrackerWrapper
    ) {
        self.frameSource = frameSource
        self.dateProvider = dateProvider
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.notificationCenter = notificationCenter
        self.delayedFramesTracker = delayedFramesTracker

        super.init()

        resetFrames()
        SentrySDKLog.debug("Initialized frame tracker")
    }
    
    deinit {
        removeObservers()
        // A frame source can retain itself while it's started, and has to be stopped on the main
        // thread. This must not capture self.
        let frameSource = self.frameSource
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread {
            frameSource.stop()
        }
    }

    // MARK: - Public Methods

    @objc
    public func start() {
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread {
            self.startInternal()
        }
    }
    
    private func startInternal() {
        guard !isStarted else { return }

        isStarted = true

        notificationCenter.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: CrossPlatformApplication.didBecomeActiveNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(willResignActive),
            name: CrossPlatformApplication.willResignActiveNotification,
            object: nil
        )

        unpause()
    }

    @objc
    public func stop() {
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread {
            self.stopInternal()
        }
    }
    
    private func stopInternal() {
        guard isStarted else { return }

        isStarted = false

        pause()

        removeObservers()

        listeners.removeAll()
    }

    private func removeObservers() {
        notificationCenter.removeObserver(
            self,
            name: CrossPlatformApplication.didBecomeActiveNotification,
            object: nil
        )

        notificationCenter.removeObserver(
            self,
            name: CrossPlatformApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc
    public func currentFrames() -> SentryScreenFrames {
#if os(iOS)
        return SentryScreenFrames(
            total: frameSource.totalFrames(),
            frozen: frozenFrames,
            slow: slowFrames,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: frozenFrameTimestamps,
            frameRateTimestamps: frameRateTimestamps
        )
#else
        return SentryScreenFrames(
            total: frameSource.totalFrames(),
            frozen: frozenFrames,
            slow: slowFrames
        )
#endif
    }

    func getFramesDelay(
        _ startSystemTimestamp: UInt64,
        endSystemTimestamp: UInt64
    ) -> SentryFramesDelayResult {
        return delayedFramesTracker.getFramesDelay(
            startSystemTimestamp,
            endSystemTimestamp: endSystemTimestamp,
            isRunning: isRunning,
            slowFrameThreshold: Self.slowFrameThreshold(currentFrameRate)
        )
    }
    
    @objc public func getFramesDelaySPI(
        _ startSystemTimestamp: UInt64,
        endSystemTimestamp: UInt64
    ) -> SentryFramesDelayResultSPI {
        let result = getFramesDelay(startSystemTimestamp, endSystemTimestamp: endSystemTimestamp)
        return .init(delayDuration: result.delayDuration, framesContributingToDelayCount: result.framesContributingToDelayCount)
    }

    // The add/remove pair below is shaped so the dispatched closures never
    // strongly capture `listener`. They capture only value-typed identity
    // (`ObjectIdentifier`) and, for `addListener`, a pre-built `WeakReference`
    // instance (whose refcount is independent of the listener's). The
    // closures are bridged through `dispatchAsyncOnMainQueueIfNotMainThread`,
    // and any strong capture of `listener` would trigger
    // `swift_unknownObjectRetain` on a mid-dealloc object if a caller invoked
    // `removeListener(self)` from inside its own `deinit` on a background
    // thread. Under iOS 26's hardened ARC, that retain is fatal
    // (`EXC_BREAKPOINT`). The `deinit`-from-background-thread shape is the
    // documented motivating crash; applying the same capture pattern to
    // `addListener` keeps the two methods consistent and forestalls
    // accidental regressions (an `addListener(self)` from `init` on a
    // background thread isn't a hardened-ARC trap shape per se, but the
    // capture-cost is identical and the symmetry is easier to maintain).
    //
    // Identity comparison via `ObjectIdentifier` is safe across the hop:
    // `existing.value` is loaded through `objc_loadWeak`, so for any listener
    // whose memory has been freed the slot reads as `nil` and the early
    // `return true` drops it without computing any identifier. We therefore
    // never call `ObjectIdentifier(live)` on a freed pointer. The captured
    // `targetIdentity` survives across the hop, but it can only match a
    // *live* `existing` — which is precisely the identity semantic `===`
    // would have provided synchronously. See the `listeners` property
    // comment above for the parallel `objc_loadWeak`-safety argument that
    // justifies `WeakReference` over `NSHashTable`.
    //
    // `[weak self]` is defense in depth — the tracker typically outlives
    // every listener, so strong capture would only extend its lifetime by
    // one main-queue trip. Weak capture matches the pattern in
    // `SentryUIDeviceWrapper.start`.
    //
    // See `testAddAndRemoveListener_DoNotRetainListenerAcrossMainQueueHop`
    // for the deterministic structural assertion of this invariant.

    @objc public func addListener(_ listener: SentryFramesTrackerListener) {
        let targetIdentity = ObjectIdentifier(listener)
        // Build the weak wrapper out here so the closure's capture list
        // contains only `ref` (whose retain count is independent of the
        // listener's), never `listener` itself. Without this hoist, the
        // closure body's `WeakReference(value: listener)` call would force
        // the closure to capture `listener` strongly.
        let ref = WeakReference(value: listener)
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
            guard let self else { return }
            // Drop zeroed refs and any existing entry for this listener to
            // avoid duplicate registrations, then append the pre-built ref.
            self.listeners.removeAll { existing in
                guard let live = existing.value else { return true }
                return ObjectIdentifier(live) == targetIdentity
            }
            self.listeners.append(ref)
        }
    }

    @objc public func removeListener(_ listener: SentryFramesTrackerListener) {
        // No pre-built `WeakReference` here — `removeListener` only filters by
        // identity, it never appends, so the closure has nothing it would need
        // to construct from `listener`.
        let targetIdentity = ObjectIdentifier(listener)
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
            self?.listeners.removeAll { existing in
                guard let live = existing.value else { return true }
                return ObjectIdentifier(live) == targetIdentity
            }
        }
    }

#if os(iOS)
    @objc public func resetProfilingTimestamps() {
        // The DisplayLink callback always runs on the main thread. We dispatch this to the main thread
        // instead to avoid using locks in the DisplayLink callback.
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread {
            self.resetProfilingTimestampsInternal()
        }
    }
#endif // os(iOS)

    // MARK: - Internal Methods

#if SENTRY_TEST || SENTRY_TEST_CI
    func setFrameSource(_ frameSource: SentryFrameSource) {
        self.frameSource.stop()
        self.frameSource = frameSource
    }

    var listenersCount: Int {
        listeners.filter { $0.value != nil }.count
    }
#endif

    @objc func resetFrames() {
        frozenFrames = 0
        slowFrames = 0

        frameSource.resetFrames()

#if os(iOS)
        resetProfilingTimestampsInternal()
#endif

        delayedFramesTracker.reset()
    }

    // MARK: - Private Methods

    @objc
    private func didBecomeActive() {
        unpause()
    }

    @objc
    private func willResignActive() {
        pause()
    }
    
    private func unpause() {
        guard !isRunning else { return }

        isRunning = true

        frameSource.start(delegate: self)
    }

    private func pause() {
        isRunning = false

        // When the frames tracker is paused, we must reset the delayed frames tracker since accurate
        // frame delay statistics cannot be provided, as we can't account for events during the pause.
        delayedFramesTracker.reset()

        frameSource.stop()
    }

    /// - Precondition: The duration is longer than the slow frame threshold.
    private func countSlowOrFrozenFrame(
        duration: CFTimeInterval,
        previousFrameSystemTimestamp: UInt64,
        thisFrameSystemTimestamp: UInt64
    ) {
        let isFrozen = duration > Self.frozenFrameThreshold
        if isFrozen {
            frozenFrames += 1
        } else {
            slowFrames += 1
        }

#if os(iOS)
        let timestamp = profilingTimestamp(systemTimestamp: thisFrameSystemTimestamp)
        let value = NSNumber(value: thisFrameSystemTimestamp - previousFrameSystemTimestamp)
        if isFrozen {
            SentrySDKLog.debug("Detected frozen frame starting at \(timestamp).")
            recordTimestamp(timestamp, value: value, array: &frozenFrameTimestamps)
        } else {
            SentrySDKLog.debug("Detected slow frame starting at \(timestamp) (frame tracker: \(self)).")
            recordTimestamp(timestamp, value: value, array: &slowFrameTimestamps)
        }
#endif // os(iOS)
    }

    private func reportNewFrame() {
        guard !listeners.isEmpty else { return }

        let newFrameDate = dateProvider.date()
        // Resolve strong references out of the weak refs and drop any zeroed
        // entries in a single pass before invoking callbacks. Callbacks may
        // mutate `listeners` (e.g., by calling removeListener on self), but we
        // iterate the local snapshot, so that is safe.
        var activeListeners: [SentryFramesTrackerListener] = []
        activeListeners.reserveCapacity(listeners.count)
        var survivingRefs: [WeakReference<SentryFramesTrackerListener>] = []
        survivingRefs.reserveCapacity(listeners.count)
        for ref in listeners {
            if let listener = ref.value {
                activeListeners.append(listener)
                survivingRefs.append(ref)
            }
        }
        listeners = survivingRefs

        for listener in activeListeners {
            listener.framesTrackerHasNewFrame(newFrameDate)
        }
    }

#if os(iOS)
    /// Continuous profiling works with dates, trace profiling with system timestamps.
    private func profilingTimestamp(systemTimestamp: UInt64) -> NSNumber {
        SentryContinuousProfiler.isCurrentlyProfiling() ?
            NSNumber(value: dateProvider.date().timeIntervalSince1970) :
            NSNumber(value: systemTimestamp)
    }

    private func recordFrameRateIfProfiling(systemTimestamp: UInt64) {
        guard SentryTraceProfiler.isCurrentlyProfiling() || SentryContinuousProfiler.isCurrentlyProfiling() else {
            return
        }

        let hasNoFrameRatesYet = frameRateTimestamps.isEmpty
        let previousFrameRate = frameRateTimestamps.last?["value"]?.uint64Value ?? 0
        guard hasNoFrameRatesYet || previousFrameRate != currentFrameRate else { return }

        let timestamp = profilingTimestamp(systemTimestamp: systemTimestamp)
        SentrySDKLog.debug("Recording new frame rate at \(timestamp).")
        recordTimestamp(timestamp, value: NSNumber(value: currentFrameRate), array: &frameRateTimestamps)
    }

    private func recordTimestamp(_ timestamp: NSNumber, value: NSNumber, array: inout SentryFrameInfoTimeSeries) {
        var shouldRecord = SentryTraceProfiler.isCurrentlyProfiling() || SentryContinuousProfiler.isCurrentlyProfiling()
#if SENTRY_TEST || SENTRY_TEST_CI
        shouldRecord = true
#endif
        if shouldRecord {
            array.append(["timestamp": timestamp, "value": value])
        }
    }
    
    private func resetProfilingTimestampsInternal() {
        SentrySDKLog.debug("Resetting profiling GPU timeseries data.")
        frozenFrameTimestamps = []
        slowFrameTimestamps = []
        frameRateTimestamps = []
    }
#endif // os(iOS)
    
    // MARK: - Static Functions
    @objc
    public static func shouldAddSlowFrozenFramesData(
        totalFrames: Int,
        slowFrames: Int,
        frozenFrames: Int
    ) -> Bool {
        let allBiggerThanOrEqualToZero = totalFrames >= 0 && slowFrames >= 0 && frozenFrames >= 0
        let oneBiggerThanZero = totalFrames > 0 || slowFrames > 0 || frozenFrames > 0

        return allBiggerThanOrEqualToZero && oneBiggerThanZero
    }
    
    static func slowFrameThreshold(_ actualFramesPerSecond: UInt64) -> CFTimeInterval {
        // Most frames take just a few microseconds longer than the optimal calculated duration.
        // Therefore we subtract one, because otherwise almost all frames would be slow.
        return 1.0 / CFTimeInterval(actualFramesPerSecond - 1)
    }
    
    // MARK: - Test Utils
    #if SENTRY_TEST || SENTRY_TEST_CI
    func manualReportNewFrame() {
        reportNewFrame()
    }
    #endif
}

// MARK: - SentryFrameSourceDelegate

extension SentryFramesTracker: SentryFrameSourceDelegate {
    func frameSource(didMeasureFrameRate frameRate: UInt64, at systemTimestamp: UInt64) {
        currentFrameRate = frameRate

#if os(iOS)
        recordFrameRateIfProfiling(systemTimestamp: systemTimestamp)
#endif // os(iOS)
    }

    func frameSource(didStartFrameAt systemTimestamp: UInt64) {
        delayedFramesTracker.setPreviousFrameSystemTimestamp(systemTimestamp)
    }

    func frameSourceDidBecomeIdle() {
        delayedFramesTracker.setPreviousFrameSystemTimestamp(SentryDelayedFramesNoFrameInFlight)
    }

    func frameSource(didDelayFrameFrom startSystemTimestamp: UInt64, to endSystemTimestamp: UInt64, duration: CFTimeInterval) {
        countSlowOrFrozenFrame(
            duration: duration,
            previousFrameSystemTimestamp: startSystemTimestamp,
            thisFrameSystemTimestamp: endSystemTimestamp
        )
        delayedFramesTracker.recordDelayedFrame(
            startSystemTimestamp,
            thisFrameSystemTimestamp: endSystemTimestamp,
            expectedDuration: Self.slowFrameThreshold(currentFrameRate),
            actualDuration: duration
        )
    }

    func frameSourceDidRenderFrame() {
        reportNewFrame()
    }
}

#endif
// swiftlint:enable file_length type_body_length missing_docs
