@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Receives normalized UI event actions from `SentryUIEventTracker`.
@_spi(Private)
@objc(SentryUIEventTrackerMode)
public protocol SentryUIEventTrackerMode: NSObjectProtocol {
    /// Handles a tracked UI event action.
    @objc(handleUIEvent:operation:accessibilityIdentifier:)
    func handleUIEvent(
        _ action: String,
        operation: String,
        accessibilityIdentifier: String?
    )
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
