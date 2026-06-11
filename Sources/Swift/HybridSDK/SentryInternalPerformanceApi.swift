// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
import UIKit

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard `SentrySDK` API surface instead.
@_spi(Private) public final class SentryInternalPerformanceApi {

    /// Enables frame tracking measurements in hybrid SDK mode.
    public var framesTrackingHybridSDKMode: Bool {
        get { PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode }
        set { PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode = newValue }
    }

    /// Whether the frames tracker is currently running.
    public var isFramesTrackingRunning: Bool {
        PrivateSentrySDKOnly.isFramesTrackingRunning
    }

    /// The current screen frame counters.
    public var currentScreenFrames: SentryScreenFrames {
        PrivateSentrySDKOnly.currentScreenFrames
    }
}
#endif
// swiftlint:enable missing_docs
