@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Helper for building app start spans in Swift.
///
/// This class provides the implementation for creating app start child spans.
/// The span descriptions and operation names defined here must be kept in sync
/// with the constants in SentryBuildAppStartSpans.m for consistency.
final class SentryAppStartSpanBuilder {

    // MARK: - Span Descriptions

    static let coldStartDescription = "Cold Start"
    static let warmStartDescription = "Warm Start"
    static let preRuntimeInitDescription = "Pre Runtime Init"
    static let runtimeInitDescription = "Runtime Init to Pre Main Initializers"
    static let uiKitInitDescription = "UIKit Init"
    static let applicationInitDescription = "Application Init"
    static let initialFrameRenderDescription = "Initial Frame Render"
    static let extendedLaunchDescription = "Extended Launch"

    // MARK: - Public API

    /// Returns the operation name for the given app start type.
    static func operation(for type: SentryAppStartType) -> String? {
        switch type {
        case .cold:
            return "app.start.cold"
        case .warm:
            return "app.start.warm"
        default:
            return nil
        }
    }

    /// Returns the measurement key for the given app start type.
    static func measurementKey(for type: SentryAppStartType) -> String? {
        switch type {
        case .cold:
            return "app_start_cold"
        case .warm:
            return "app_start_warm"
        default:
            return nil
        }
    }

    /// Returns the app start type string for the context data.
    static func appStartTypeString(for measurement: SentryAppStartMeasurement) -> String {
        let baseType = measurement.type == .cold ? "cold" : "warm"
        return measurement.isPreWarmed ? "\(baseType).prewarmed" : baseType
    }

    /// Returns the type description for the given app start type.
    static func typeDescription(for type: SentryAppStartType) -> String? {
        switch type {
        case .cold:
            return coldStartDescription
        case .warm:
            return warmStartDescription
        default:
            return nil
        }
    }

    /// Builds app start spans using the Span protocol.
    ///
    /// This method creates the standard app start span hierarchy:
    /// - Main span (Cold Start / Warm Start)
    /// - Pre Runtime Init (if not pre-warmed)
    /// - Runtime Init to Pre Main Initializers (if not pre-warmed)
    /// - UIKit Init
    /// - Application Init
    /// - Initial Frame Render
    /// - Extended Launch (if extendedEndDate is provided)
    ///
    /// - Parameters:
    ///   - span: The parent span to attach children to
    ///   - measurement: The app start measurement data
    ///   - operation: The operation name (app.start.cold or app.start.warm)
    ///   - extendedEndDate: Optional date when the extended launch finished
    static func buildSpans(
        on span: Span,
        measurement: SentryAppStartMeasurement,
        operation: String,
        extendedEndDate: Date?
    ) {
        let appStartEndTimestamp = measurement.appStartTimestamp.addingTimeInterval(measurement.duration)

        // Main app start span
        let typeDescription = measurement.type == .cold ? coldStartDescription : warmStartDescription
        let appStartSpan = span.startChild(operation: operation, description: typeDescription)
        appStartSpan.startTimestamp = measurement.appStartTimestamp
        appStartSpan.timestamp = appStartEndTimestamp
        appStartSpan.finish(status: SentrySpanStatus.ok)

        // Pre-warmed apps skip the pre-main phases
        if !measurement.isPreWarmed {
            // Pre Runtime Init span
            let premainSpan = span.startChild(operation: operation, description: preRuntimeInitDescription)
            premainSpan.startTimestamp = measurement.appStartTimestamp
            premainSpan.timestamp = measurement.runtimeInitTimestamp
            premainSpan.finish(status: SentrySpanStatus.ok)

            // Runtime Init to Pre Main Initializers span
            let runtimeInitSpan = span.startChild(operation: operation, description: runtimeInitDescription)
            runtimeInitSpan.startTimestamp = measurement.runtimeInitTimestamp
            runtimeInitSpan.timestamp = measurement.moduleInitializationTimestamp
            runtimeInitSpan.finish(status: SentrySpanStatus.ok)
        }

        // UIKit Init span
        let uiKitInitSpan = span.startChild(operation: operation, description: uiKitInitDescription)
        uiKitInitSpan.startTimestamp = measurement.moduleInitializationTimestamp
        uiKitInitSpan.timestamp = measurement.sdkStartTimestamp
        uiKitInitSpan.finish(status: SentrySpanStatus.ok)

        // Application Init span
        let appInitSpan = span.startChild(operation: operation, description: applicationInitDescription)
        appInitSpan.startTimestamp = measurement.sdkStartTimestamp
        appInitSpan.timestamp = measurement.didFinishLaunchingTimestamp
        appInitSpan.finish(status: SentrySpanStatus.ok)

        // Initial Frame Render span
        let frameRenderSpan = span.startChild(operation: operation, description: initialFrameRenderDescription)
        frameRenderSpan.startTimestamp = measurement.didFinishLaunchingTimestamp
        frameRenderSpan.timestamp = appStartEndTimestamp
        frameRenderSpan.finish(status: SentrySpanStatus.ok)

        // Extended Launch span (if applicable)
        if let extendedEndDate = extendedEndDate {
            let extendedSpan = span.startChild(operation: operation, description: extendedLaunchDescription)
            extendedSpan.startTimestamp = appStartEndTimestamp
            extendedSpan.timestamp = extendedEndDate
            extendedSpan.finish(status: SentrySpanStatus.ok)
        }
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
