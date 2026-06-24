// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Provides access to frame tracking metrics for hybrid SDKs.
public struct SentryInternalPerformanceApi {

    typealias Dependencies = FramesTrackingProvider

    private let framesTracker: SentryFramesTracker

    init(dependencies: Dependencies) {
        self.framesTracker = dependencies.framesTracker
    }

    /// Whether frames tracking is operating in hybrid SDK mode.
    public var framesTrackingHybridSDKMode: Bool {
        get { PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode }
        nonmutating set { PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode = newValue }
    }

    /// Whether frames tracking is currently running.
    public var isFramesTrackingRunning: Bool {
        framesTracker.isRunning
    }

    /// The current screen frame metrics.
    @_spi(Private)
    public var currentScreenFrames: SentryScreenFrames {
        framesTracker.currentFrames()
    }
}

#endif
// swiftlint:enable missing_docs
