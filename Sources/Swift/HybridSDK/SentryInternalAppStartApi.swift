// swiftlint:disable missing_docs
import Foundation

/// Provides app start measurement access for hybrid SDKs.
public struct SentryInternalAppStartApi {

    init() {}

    /// When enabled, the SDK won't send the app start measurement with the first transaction.
    /// Instead, the SDK measures the app start and calls `onMeasurementAvailable`.
    public var hybridSDKMode: Bool {
        get { PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode }
        nonmutating set { PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = newValue }
    }

    /// Returns the app start measurement serialized as a dictionary with span data,
    /// or `nil` if no measurement is available.
    public var measurementWithSpans: [String: Any]? {
        PrivateSentrySDKOnly.appStartMeasurementWithSpans() as [String: Any]?
    }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// Returns the current app start measurement, or `nil` if not yet available.
    public var measurement: SentryAppStartMeasurement? {
        PrivateSentrySDKOnly.appStartMeasurement
    }

    /// Callback invoked when the app start measurement becomes available.
    public var onMeasurementAvailable: ((SentryAppStartMeasurement?) -> Void)? {
        get { PrivateSentrySDKOnly.onAppStartMeasurementAvailable }
        nonmutating set { PrivateSentrySDKOnly.onAppStartMeasurementAvailable = newValue }
    }
#endif
}
// swiftlint:enable missing_docs
