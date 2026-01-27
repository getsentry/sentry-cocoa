import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit
#endif

/// Enriches the event context by adding additional information.
@objc @_spi(Private) public protocol SentryEventContextEnricher {
    /// Enriches the event context dictionary by adding additional information.
    /// - Parameter context: The current event context dictionary.
    /// - Returns: The enriched context dictionary with additional information added.
    func enrichEventContext(_ context: [String: Any]) -> [String: Any]
}

/// Default implementation of event context enrichment.
/// On UIKit platforms, adds in_foreground and is_active fields to the app context based on UIApplicationState.
/// On other platforms, returns the context unchanged.
class SentryDefaultEventContextEnricher: SentryEventContextEnricher {

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
    private let applicationStateProvider: () -> UIApplication.State?

    init(applicationStateProvider: @escaping () -> UIApplication.State?) {
        self.applicationStateProvider = applicationStateProvider
    }

    func enrichEventContext(_ context: [String: Any]) -> [String: Any] {
        // Check if both fields are already set
        if let appContext = context["app"] as? [String: Any],
           appContext["in_foreground"] != nil && appContext["is_active"] != nil {
            // Both fields already exist, don't modify
            return context
        }

        // Get application state
        guard let appState = applicationStateProvider() else {
            SentrySDKLog.warning("Failed to retrieve application state. Can't enrich event context with in_foreground and is_active fields.")
            return context
        }

        // Add app state information
        var mutableContext = context
        var appContext = (mutableContext["app"] as? [String: Any]) ?? [:]

        let isActive = appState == .active
        let inForeground = appState != .background

        if appContext["in_foreground"] == nil {
            appContext["in_foreground"] = inForeground
        }

        if appContext["is_active"] == nil {
            appContext["is_active"] = isActive
        }

        mutableContext["app"] = appContext
        return mutableContext
    }
#else
    init() {
    }

    func enrichEventContext(_ context: [String: Any]) -> [String: Any] {
        // No-op on non-UIKit platforms
        return context
    }
#endif
}
