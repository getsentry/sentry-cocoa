// swiftlint:disable missing_docs
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

internal import _SentryPrivate
import Foundation

/// Creates TTID and TTFD spans, using the tracer's wait-for-children behavior
/// to keep the transaction open until full display is reported when requested.
@_spi(Private) @objc(SentryTimeToDisplayTracker)
public class SentryTimeToDisplayTracker: NSObject, SentryFramesTrackerListener, SentryInitialDisplayReporting {
    @objc public private(set) weak var initialDisplaySpan: (any Span)?
    @objc public private(set) weak var fullDisplaySpan: (any Span)?
    @objc public let waitForFullDisplay: Bool

    private let name: String
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private var initialDisplayReported = false
    private var fullyDisplayedReported = false

    @objc public init(name: String, waitForFullDisplay: Bool, dispatchQueueWrapper: SentryDispatchQueueWrapper) {
        self.name = name
        self.waitForFullDisplay = waitForFullDisplay
        self.dispatchQueueWrapper = dispatchQueueWrapper
        super.init()
    }

    // SentryTracer belongs to _SentryPrivate and cannot appear in the exported
    // Swift interface. Keep the typed entry point for internal Swift callers.
    @objc(startForTracer:)
    public func startForTracer(_ tracer: AnyObject) -> Bool {
        guard let tracer = tracer as? SentryTracer else { return false }
        return start(for: tracer)
    }

    @discardableResult
    func start(for tracer: SentryTracer) -> Bool {
        guard SentryDependencyContainer.sharedInstance().framesTracker.isRunning else {
            SentrySDKLog.debug("Skipping TTID/TTFD spans, because can't report them correctly when the frames tracker isn't running.")
            return false
        }

        SentrySDKLog.debug("Starting initial display span")
        initialDisplaySpan = tracer.startChild(operation: SentrySpanOperationUiLoadInitialDisplay, description: "\(name) initial display")
        initialDisplaySpan?.origin = SentryTraceOriginAutoUITimeToDisplay

        if waitForFullDisplay {
            SentrySDKLog.debug("Starting full display span")
            fullDisplaySpan = tracer.startChild(operation: SentrySpanOperationUiLoadFullDisplay, description: "\(name) full display")
            fullDisplaySpan?.origin = SentryTraceOriginManualUITimeToDisplay

            // TTID and TTFD share the transaction's start timestamp.
            fullDisplaySpan?.startTimestamp = tracer.startTimestamp
        }
        initialDisplaySpan?.startTimestamp = tracer.startTimestamp

        SentryDependencyContainer.sharedInstance().framesTracker.addListener(self)

        tracer.shouldIgnoreWaitForChildrenCallback = { span in
            span.origin == SentryTraceOriginAutoUITimeToDisplay
        }
        // The tracer owns the tracker's lifetime. The tracker only holds weak spans.
        tracer.finishCallback = { [self] tracer in
            SentryDependencyContainer.sharedInstance().framesTracker.removeListener(self)

            // Keep the weak spans alive throughout the callback if the tracer's
            // children are released concurrently.
            let initialSpan = initialDisplaySpan
            let fullSpan = fullDisplaySpan

            if let initialSpan {
                if !initialSpan.isFinished {
                    initialSpan.finish()
                }
                initialSpan.startTimestamp = tracer.startTimestamp
                addTimeToDisplayMeasurement(initialSpan, name: "time_to_initial_display")
            }

            guard let fullSpan else { return }
            fullSpan.startTimestamp = tracer.startTimestamp
            addTimeToDisplayMeasurement(fullSpan, name: "time_to_full_display")

            guard fullSpan.status == .deadlineExceeded else { return }
            if let initialSpan {
                fullSpan.timestamp = initialSpan.timestamp
            }
            fullSpan.spanDescription = "\(fullSpan.spanDescription ?? "(null)") - Deadline Exceeded"
            addTimeToDisplayMeasurement(fullSpan, name: "time_to_full_display")
        }

        return true
    }

    @objc public func reportInitialDisplay() {
        SentrySDKLog.debug("Reporting initial display for \(name)")
        initialDisplayReported = true
    }

    @objc public func reportFullyDisplayed() {
        SentrySDKLog.debug("Reporting full display for \(name)")
        // All other accesses run on the main thread. Dispatch rather than lock.
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [self] in
            fullyDisplayedReported = true
        }
    }

    @objc public func finishSpansIfNotFinished() {
        SentryDependencyContainer.sharedInstance().framesTracker.removeListener(self)

        if initialDisplaySpan?.isFinished != true {
            initialDisplaySpan?.finish()
        }

        if fullDisplaySpan?.isFinished != true {
            if fullyDisplayedReported {
                SentrySDKLog.debug("SentrySDK.reportFullyDisplayed() was called but didn't receive a new frame to finish the TTFD span. Finishing the full display span so the SDK can start a new time to display tracker.")
                fullDisplaySpan?.finish()
                return
            }

            SentrySDKLog.warning("You didn't call SentrySDK.reportFullyDisplayed() for UIViewController: \(name). Finishing full display span with status: \(nameForSentrySpanStatus(.deadlineExceeded)).")
            fullDisplaySpan?.finish(status: .deadlineExceeded)
        }
    }

    public func framesTrackerHasNewFrame(_ newFrameDate: Date) {
        // TTID and TTFD measure when screen content changes, so wait for the
        // next frame to be drawn before finishing their spans.
        if initialDisplayReported && initialDisplaySpan?.isFinished != true {
            SentrySDKLog.debug("Finishing initial display span")
            initialDisplaySpan?.timestamp = newFrameDate
            initialDisplaySpan?.finish()
            if !waitForFullDisplay {
                SentryDependencyContainer.sharedInstance().framesTracker.removeListener(self)
                #if os(iOS)
                if sentry_isLaunchProfileCorrelatedToTraces() {
                    sentry_stopAndDiscardLaunchProfileTracer(SentrySDKInternal.currentHub())
                }
                #endif
            }
        }

        if waitForFullDisplay && fullyDisplayedReported && fullDisplaySpan?.isFinished != true
            && initialDisplaySpan?.isFinished == true {
            SentrySDKLog.debug("Finishing full display span")
            fullDisplaySpan?.timestamp = newFrameDate
            fullDisplaySpan?.finish()
            #if os(iOS)
            if sentry_isLaunchProfileCorrelatedToTraces() {
                sentry_stopAndDiscardLaunchProfileTracer(SentrySDKInternal.currentHub())
            }
            #endif
        }

        if initialDisplaySpan?.isFinished == true && fullDisplaySpan?.isFinished == true {
            SentryDependencyContainer.sharedInstance().framesTracker.removeListener(self)
        }
    }

    private func addTimeToDisplayMeasurement(_ span: any Span, name: String) {
        guard let startTimestamp = span.startTimestamp else { return }
        let duration = (span.timestamp?.timeIntervalSince(startTimestamp) ?? 0) * 1_000
        span.setMeasurement(name: name, value: NSNumber(value: duration), unit: MeasurementUnitDuration.millisecond)
    }
}

#endif
// swiftlint:enable missing_docs
