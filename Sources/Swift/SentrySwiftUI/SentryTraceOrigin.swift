#if canImport(SwiftUI) && (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Swift compatibility wrapper for trace origins.
/// The canonical constants are in SentryTraceOrigin.h.
/// These values must match SentryTraceOrigin.m.
@available(*, deprecated, message: "Use SentryTraceOriginAutoUISwiftUI and other constants from the Sentry module instead")
public enum SentryTraceOrigin {
    /// Trace origin for SwiftUI views.
    public static let autoUISwiftUI = "auto.ui.swift_ui"
    /// Trace origin for time-to-display spans.
    public static let autoUITimeToDisplay = "auto.ui.time_to_display"
}

#endif
