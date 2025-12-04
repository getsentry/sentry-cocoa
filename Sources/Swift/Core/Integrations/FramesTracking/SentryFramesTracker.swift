// swiftlint:disable file_length type_body_length
@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
import UIKit
private typealias CrossPlatformApplication = UIApplication
#elseif os(macOS)
import AppKit
private typealias CrossPlatformApplication = NSApplication
#endif

#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT

@_spi(Private) @objc
public protocol SentryFramesTrackerListener: NSObjectProtocol {
    func framesTrackerHasNewFrame(_ newFrameDate: Date)
}

@_spi(Private) @objc
public class SentryFramesTracker: NSObject {

    var isStarted: Bool = false
    @objc public private(set) var isRunning: Bool = false
    
    // MARK: Private properties
    private var lock = NSLock()
    private var previousFrameTimestamp: CFTimeInterval = SentryFramesTracker.previousFrameInitialValue
    private var previousFrameSystemTimestamp: UInt64 = 0
    private var currentFrameRate: UInt64 = 60
    private var listeners: NSHashTable<SentryFramesTrackerListener>

#if os(iOS)
    private var frozenFrameTimestamps = SentryFrameInfoTimeSeries()
    private var slowFrameTimestamps = SentryFrameInfoTimeSeries()
    private var frameRateTimestamps = SentryFrameInfoTimeSeries()
#endif // os(iOS)

    // Frame counters - accessed only from main thread (display link callback)
    private var totalFrames: UInt = 0
    private var slowFrames: UInt = 0
    private var frozenFrames: UInt = 0

    private var displayLinkWrapper: SentryDisplayLinkWrapper
    private let dateProvider: SentryCurrentDateProvider
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let notificationCenter: SentryNSNotificationCenterWrapper
    private var delayedFramesTracker: SentryDelayedFramesTrackerWrapper
    
    private static let frozenFrameThreshold: CFTimeInterval = 0.7
    private static let previousFrameInitialValue: CFTimeInterval = -1

    init(
        displayLinkWrapper: SentryDisplayLinkWrapper,
        dateProvider: SentryCurrentDateProvider,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        notificationCenter: SentryNSNotificationCenterWrapper,
        delayedFramesTracker: SentryDelayedFramesTrackerWrapper
    ) {
        self.displayLinkWrapper = displayLinkWrapper
        self.dateProvider = dateProvider
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.notificationCenter = notificationCenter
        self.delayedFramesTracker = delayedFramesTracker
        self.listeners = NSHashTable<SentryFramesTrackerListener>.weakObjects()

        super.init()

        resetFrames()
        SentrySDKLog.debug("Initialized frame tracker")
    }

    // MARK: - Public Methods

    @objc
    public func start() {
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
        guard isStarted else { return }

        isStarted = false

        pause()

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

        lock.synchronized {
            listeners.removeAllObjects()
        }
    }

    @objc
    public func currentFrames() -> SentryScreenFrames {
#if os(iOS)
        return SentryScreenFrames(
            total: totalFrames,
            frozen: frozenFrames,
            slow: slowFrames,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: frozenFrameTimestamps,
            frameRateTimestamps: frameRateTimestamps
        )
#else
        return SentryScreenFrames(
            total: totalFrames,
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

    @objc public func addListener(_ listener: SentryFramesTrackerListener) {
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread {
            self.listeners.add(listener)
        }
    }

    @objc public func removeListener(_ listener: SentryFramesTrackerListener) {
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread {
            self.listeners.remove(listener)
        }
    }
    
    deinit {
        stop()
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
    @objc func setDisplayLinkWrapper(_ displayLinkWrapper: SentryDisplayLinkWrapper) {
        self.displayLinkWrapper = displayLinkWrapper
    }
    
    var listenersCount: Int {
        listeners.count
    }
#endif

    @objc func resetFrames() {
        totalFrames = 0
        frozenFrames = 0
        slowFrames = 0

        previousFrameTimestamp = Self.previousFrameInitialValue

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

        // Reset the previous frame timestamp to avoid wrong metrics being collected
        previousFrameTimestamp = Self.previousFrameInitialValue
        displayLinkWrapper.link(withTarget: self, selector: #selector(displayLinkCallback))
    }

    private func pause() {
        isRunning = false

        // When the frames tracker is paused, we must reset the delayed frames tracker since accurate
        // frame delay statistics cannot be provided, as we can't account for events during the pause.
        delayedFramesTracker.reset()

        displayLinkWrapper.invalidate()
    }

// swiftlint:disable file_length function_body_length
    @objc
    private func displayLinkCallback() {
        let thisFrameTimestamp = displayLinkWrapper.timestamp
        let thisFrameSystemTimestamp = dateProvider.systemTime()

        if previousFrameTimestamp == Self.previousFrameInitialValue {
            previousFrameTimestamp = thisFrameTimestamp
            previousFrameSystemTimestamp = thisFrameSystemTimestamp
            delayedFramesTracker.setPreviousFrameSystemTimestamp(thisFrameSystemTimestamp)
            reportNewFrame()
            return
        }

        // Calculate the actual frame rate as pointed out by the Apple docs:
        // https://developer.apple.com/documentation/quartzcore/cadisplaylink?language=objc The actual
        // frame rate can change at any time by setting preferredFramesPerSecond or due to ProMotion
        // display, low power mode, critical thermal state, and accessibility settings. Therefore we
        // need to check the frame rate for every callback.
        // targetTimestamp is only available on iOS 10.0 and tvOS 10.0 and above. We use a fallback of
        // 60 fps.
        currentFrameRate = 60
        if displayLinkWrapper.targetTimestamp != displayLinkWrapper.timestamp {
            currentFrameRate = UInt64(round(
                1 / (displayLinkWrapper.targetTimestamp - displayLinkWrapper.timestamp)
            ))
        }

#if os(iOS)
        let thisFrameNSDate = dateProvider.date()
        let isContinuousProfiling = SentryContinuousProfiler.isCurrentlyProfiling()
        let profilingTimestamp = isContinuousProfiling ?
            NSNumber(value: thisFrameNSDate.timeIntervalSince1970) :
            NSNumber(value: thisFrameSystemTimestamp)

        if SentryTraceProfiler.isCurrentlyProfiling() || isContinuousProfiling {
            let hasNoFrameRatesYet = frameRateTimestamps.isEmpty
            let previousFrameRate = frameRateTimestamps.last?["value"]?.uint64Value ?? 0
            let frameRateChanged = previousFrameRate != currentFrameRate
            let shouldRecordNewFrameRate = hasNoFrameRatesYet || frameRateChanged

            if shouldRecordNewFrameRate {
                SentrySDKLog.debug("Recording new frame rate at \(profilingTimestamp).")
                recordTimestamp(profilingTimestamp, value: NSNumber(value: currentFrameRate), array: &frameRateTimestamps)
            }
        }
#endif // os(iOS)

        let frameDuration = thisFrameTimestamp - previousFrameTimestamp
        let slowThreshold = Self.slowFrameThreshold(currentFrameRate)

        if frameDuration > slowThreshold && frameDuration <= Self.frozenFrameThreshold {
            slowFrames += 1
#if os(iOS)
            SentrySDKLog.debug("Detected slow frame starting at \(profilingTimestamp) (frame tracker: \(self)).")
            recordTimestamp(
                profilingTimestamp,
                value: NSNumber(value: thisFrameSystemTimestamp - previousFrameSystemTimestamp),
                array: &slowFrameTimestamps
            )
#endif // os(iOS)
        } else if frameDuration > Self.frozenFrameThreshold {
            frozenFrames += 1
#if os(iOS)
            SentrySDKLog.debug("Detected frozen frame starting at \(profilingTimestamp).")
            recordTimestamp(
                profilingTimestamp,
                value: NSNumber(value: thisFrameSystemTimestamp - previousFrameSystemTimestamp),
                array: &frozenFrameTimestamps
            )
#endif // os(iOS)
        }

        if frameDuration > slowThreshold {
            delayedFramesTracker.recordDelayedFrame(
                previousFrameSystemTimestamp,
                thisFrameSystemTimestamp: thisFrameSystemTimestamp,
                expectedDuration: slowThreshold,
                actualDuration: frameDuration
            )
        } else {
            delayedFramesTracker.setPreviousFrameSystemTimestamp(thisFrameSystemTimestamp)
        }

        totalFrames += 1
        previousFrameTimestamp = thisFrameTimestamp
        previousFrameSystemTimestamp = thisFrameSystemTimestamp
        reportNewFrame()
    }
// swiftlint:enable file_length function_body_length

    private func reportNewFrame() {
        let newFrameDate = dateProvider.date()
        // We need to copy the list because some listeners will remove themselves
        // from the list during the callback, causing a crash during iteration.
        let listenersArray = self.listeners.allObjects
        for listener in listenersArray {
            listener.framesTrackerHasNewFrame(newFrameDate)
        }
    }

#if os(iOS)
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
}

#endif
// swiftlint:enable file_length type_body_length
