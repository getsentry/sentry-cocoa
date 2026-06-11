@_implementationOnly import _SentryPrivate
import Foundation

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard `SentrySDK` API surface instead.
@_spi(Private) public final class SentryInternalAppStartApi {

    /// When enabled, the SDK won't send the app start measurement with the
    /// first transaction. Instead, the SDK measures the app start and calls
    /// `onMeasurementAvailable`.
    public var hybridSDKMode: Bool {
        get { PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode }
        set { PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = newValue }
    }

    /// The app start measurement serialized as a dictionary with span data,
    /// or `nil` if not available.
    public var measurementWithSpans: [String: Any]? {
        PrivateSentrySDKOnly.appStartMeasurementWithSpans()
    }

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    /// The most recent app start measurement, or `nil` if not yet available.
    public var measurement: SentryAppStartMeasurement? {
        PrivateSentrySDKOnly.appStartMeasurement
    }

    /// A callback invoked when the app start measurement becomes available.
    public var onMeasurementAvailable: ((SentryAppStartMeasurement?) -> Void)? {
        get { PrivateSentrySDKOnly.onAppStartMeasurementAvailable }
        set { PrivateSentrySDKOnly.onAppStartMeasurementAvailable = newValue }
    }
    #endif
}
