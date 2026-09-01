// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

/// Provides app start measurement access for hybrid SDKs.
public struct SentryInternalAppStartApi {

    init() {}

    /// When enabled, the SDK won't send the app start measurement with the first transaction.
    /// Instead, the SDK measures the app start and calls `onMeasurementAvailable`.
    public var hybridSDKMode: Bool {
        get { SentrySDKInternal.appStartMeasurementHybridSDKMode }
        nonmutating set { SentrySDKInternal.appStartMeasurementHybridSDKMode = newValue }
    }

    /// Returns the app start measurement serialized as a dictionary with span data,
    /// or `nil` if no measurement is available.
    public var measurementWithSpans: [String: Any]? {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        guard let measurement = SentrySDKInternal.getAppStartMeasurement() else {
            return nil
        }

        let appStartTimestampMs = measurement.appStartTimestamp.timeIntervalSince1970 * 1_000
        let runtimeInitTimestampMs = measurement.runtimeInitTimestamp.timeIntervalSince1970 * 1_000
        let moduleInitializationTimestampMs = measurement.moduleInitializationTimestamp.timeIntervalSince1970 * 1_000
        let sdkStartTimestampMs = measurement.sdkStartTimestamp.timeIntervalSince1970 * 1_000
        let uiKitInitSpan: [String: Any] = [
            "description": "UIKit init",
            "start_timestamp_ms": moduleInitializationTimestampMs,
            "end_timestamp_ms": sdkStartTimestampMs
        ]
        let spans: [[String: Any]] = measurement.isPreWarmed ? [
            [
                "description": "Pre Runtime Init",
                "start_timestamp_ms": appStartTimestampMs,
                "end_timestamp_ms": runtimeInitTimestampMs
            ],
            [
                "description": "Runtime init to Pre Main initializers",
                "start_timestamp_ms": runtimeInitTimestampMs,
                "end_timestamp_ms": moduleInitializationTimestampMs
            ],
            uiKitInitSpan
        ] : [uiKitInitSpan]

        return [
            "type": SentryAppStartTypeToString.convert(measurement.type),
            "is_pre_warmed": measurement.isPreWarmed,
            "app_start_timestamp_ms": appStartTimestampMs,
            "runtime_init_timestamp_ms": runtimeInitTimestampMs,
            "module_initialization_timestamp_ms": moduleInitializationTimestampMs,
            "sdk_start_timestamp_ms": sdkStartTimestampMs,
            "spans": spans
        ]
#else
        return nil
#endif
    }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// Returns the current app start measurement, or `nil` if not yet available.
    public var measurement: SentryAppStartMeasurement? {
        SentrySDKInternal.getAppStartMeasurement()
    }

    /// Callback invoked when the app start measurement becomes available.
    public var onMeasurementAvailable: ((SentryAppStartMeasurement?) -> Void)? {
        get { SentrySDKInternal.onAppStartMeasurementAvailable }
        nonmutating set { SentrySDKInternal.onAppStartMeasurementAvailable = newValue }
    }
#endif
}
// swiftlint:enable missing_docs
