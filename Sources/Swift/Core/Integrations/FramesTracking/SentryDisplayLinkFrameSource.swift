#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

import Foundation

/// The frame source for OS versions without `UIUpdateLink`.
///
/// A `CADisplayLink` calls back for every frame of the display for as long as it's linked, even when
/// nothing on screen changes. The time between two callbacks is the duration of a frame.
final class SentryDisplayLinkFrameSource: NSObject, SentryFrameSource {

    private static let previousFrameInitialValue: CFTimeInterval = -1

    private let displayLinkWrapper: SentryDisplayLinkWrapper
    private let dateProvider: SentryCurrentDateProvider
    private weak var delegate: SentryFrameSourceDelegate?

    // Accessed only from main thread (display link callback)
    private var previousFrameTimestamp = SentryDisplayLinkFrameSource.previousFrameInitialValue
    private var previousFrameSystemTimestamp: UInt64 = 0

    /// Written by the display link callback, read by the threads that start and finish spans.
    private let frameCount = SentryMutex<UInt>(0)

    // The display link reports every frame anyway.
    var requiresContinuousFrames = false

    init(displayLinkWrapper: SentryDisplayLinkWrapper, dateProvider: SentryCurrentDateProvider) {
        self.displayLinkWrapper = displayLinkWrapper
        self.dateProvider = dateProvider
        super.init()
    }

    func start(delegate: SentryFrameSourceDelegate) {
        self.delegate = delegate

        // Reset the previous frame timestamp to avoid wrong metrics being collected
        previousFrameTimestamp = Self.previousFrameInitialValue
        displayLinkWrapper.link(withTarget: self, selector: #selector(displayLinkCallback))
    }

    func stop() {
        // The display link retains this object until it's invalidated. Calling this is thread-safe.
        displayLinkWrapper.invalidate()
    }

    func totalFrames() -> UInt {
        frameCount.withLock { $0 }
    }

    func resetFrames() {
        frameCount.withLock { $0 = 0 }
        previousFrameTimestamp = Self.previousFrameInitialValue
    }

    @objc
    private func displayLinkCallback() {
        let thisFrameTimestamp = displayLinkWrapper.timestamp
        let thisFrameSystemTimestamp = dateProvider.systemTime()

        if previousFrameTimestamp == Self.previousFrameInitialValue {
            previousFrameTimestamp = thisFrameTimestamp
            previousFrameSystemTimestamp = thisFrameSystemTimestamp
            delegate?.frameSource(didStartFrameAt: thisFrameSystemTimestamp)
            delegate?.frameSourceDidRenderFrame()
            return
        }

        // Calculate the actual frame rate as pointed out by the Apple docs:
        // https://developer.apple.com/documentation/quartzcore/cadisplaylink?language=objc The actual
        // frame rate can change at any time by setting preferredFramesPerSecond or due to ProMotion
        // display, low power mode, critical thermal state, and accessibility settings. Therefore we
        // need to check the frame rate for every callback.
        // targetTimestamp is only available on iOS 10.0 and tvOS 10.0 and above. We use a fallback of
        // 60 fps.
        var frameRate: UInt64 = 60
        if displayLinkWrapper.targetTimestamp != displayLinkWrapper.timestamp {
            frameRate = UInt64(round(
                1 / (displayLinkWrapper.targetTimestamp - displayLinkWrapper.timestamp)
            ))
        }
        delegate?.frameSource(didMeasureFrameRate: frameRate, at: thisFrameSystemTimestamp)

        let frameDuration = thisFrameTimestamp - previousFrameTimestamp

        if frameDuration > SentryFramesTracker.slowFrameThreshold(frameRate) {
            delegate?.frameSource(
                didDelayFrameFrom: previousFrameSystemTimestamp,
                to: thisFrameSystemTimestamp,
                duration: frameDuration
            )
        } else {
            delegate?.frameSource(didStartFrameAt: thisFrameSystemTimestamp)
        }

        frameCount.withLock { $0 += 1 }
        previousFrameTimestamp = thisFrameTimestamp
        previousFrameSystemTimestamp = thisFrameSystemTimestamp
        delegate?.frameSourceDidRenderFrame()
    }
}

#if SENTRY_TEST || SENTRY_TEST_CI
extension SentryFramesTracker {
    /// Most tests drive the tracker frame by frame with a `TestDisplayLinkWrapper`.
    convenience init(
        displayLinkWrapper: SentryDisplayLinkWrapper,
        dateProvider: SentryCurrentDateProvider,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        notificationCenter: SentryNSNotificationCenterWrapper,
        delayedFramesTracker: SentryDelayedFramesTrackerWrapper
    ) {
        self.init(
            frameSource: SentryDisplayLinkFrameSource(displayLinkWrapper: displayLinkWrapper, dateProvider: dateProvider),
            dateProvider: dateProvider,
            dispatchQueueWrapper: dispatchQueueWrapper,
            notificationCenter: notificationCenter,
            delayedFramesTracker: delayedFramesTracker
        )
    }

    /// Makes the tracker use a display link, also on OS versions on which it otherwise doesn't.
    func setDisplayLinkWrapper(_ displayLinkWrapper: SentryDisplayLinkWrapper) {
        setFrameSource(SentryDisplayLinkFrameSource(displayLinkWrapper: displayLinkWrapper, dateProvider: dateProvider))
    }
}
#endif

#endif
