#if canImport(SwiftUI) && (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Swift compatibility wrapper for span operations.
/// The canonical constants are in SentrySpanOperation.h.
/// These values must match SentrySpanOperation.m.
@available(*, deprecated, message: "Use SentrySpanOperationUiLoad and other constants from the Sentry module instead")
public enum SentrySpanOperation {
    /// Span operation for UI load operations.
    public static let uiLoad = "ui.load"
}

#endif
