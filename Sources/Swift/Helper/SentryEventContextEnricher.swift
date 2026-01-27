import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit
#endif

/// Enriches the event context by adding app state information.
@objc @_spi(Private) public protocol SentryEventContextEnricher {
    /// Enriches the event context dictionary with app state fields (in_foreground and is_active).
    /// - Parameter context: The current event context dictionary, or nil if no context exists.
    /// - Returns: The enriched context dictionary with app state information added.
    func enrichWithAppState(_ context: [String: Any]?) -> [String: Any]
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

    func enrichWithAppState(_ context: [String: Any]?) -> [String: Any] {
        let contextToEnrich = context ?? [:]

        // Check if both fields are already set
        if let appContext = contextToEnrich["app"] as? [String: Any],
           appContext["in_foreground"] != nil && appContext["is_active"] != nil {
            // Both fields already exist, don't modify
            return contextToEnrich
        }

        // Get application state
        guard let appState = applicationStateProvider() else {
            SentrySDKLog.warning("Failed to retrieve application state. Can't enrich event context with in_foreground and is_active fields.")
            return contextToEnrich
        }

        // Add app state information
        var mutableContext = contextToEnrich
        var appContext: [String: Any]

        if let existingAppContext = mutableContext["app"] as? [String: Any] {
            appContext = existingAppContext
        } else {
            appContext = [:]
        }

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

    func enrichWithAppState(_ context: [String: Any]?) -> [String: Any] {
        // No-op on non-UIKit platforms
        return context ?? [:]
    }
#endif
}
