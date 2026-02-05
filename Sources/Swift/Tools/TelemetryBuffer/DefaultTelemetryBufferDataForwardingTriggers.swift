// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
private typealias CrossPlatformApplication = UIApplication
#elseif os(macOS) && !SENTRY_NO_UI_FRAMEWORK
import AppKit
private typealias CrossPlatformApplication = NSApplication
#endif

@_spi(Private) public protocol TelemetryBufferItemForwardingTriggers {
    /// Registers a single callback to be invoked on app lifecycle events.
    /// - Important: Only supports ONE callback per instance. Multiple calls will replace the previous callback.
    func registerForwardItemsCallback(forwardItems: @escaping () -> Void)
}

struct NoOpTelemetryBufferDataForwardingTriggers: TelemetryBufferItemForwardingTriggers {
    func registerForwardItemsCallback(forwardItems: @escaping () -> Void) {
        // Empty on purpose
    }
}

#if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Triggers data forwarding on app lifecycle events (willResignActive, willTerminate).
/// Uses multiple instances (one per buffer) instead of a shared singleton with callback list to:
/// - Avoid shared mutable state and thread-safety concerns
/// - Enable clear ownership: each buffer controls its own lifecycle trigger
/// - Improve testability: triggers can be tested in isolation
/// - Simplify cleanup: automatic deregistration when buffer is deallocated
final class DefaultTelemetryBufferDataForwardingTriggers: TelemetryBufferItemForwardingTriggers {

    private let notificationCenter: SentryNSNotificationCenterWrapper
    private var forwardItems: (() -> Void)?

    init(notificationCenter: SentryNSNotificationCenterWrapper) {
        self.notificationCenter = notificationCenter

        notificationCenter.addObserver(
            self,
            selector: #selector(willResignActive),
            name: CrossPlatformApplication.willResignActiveNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(willTerminate),
            name: CrossPlatformApplication.willTerminateNotification,
            object: nil
        )
    }

    func registerForwardItemsCallback(forwardItems: @escaping () -> Void) {
        self.forwardItems = forwardItems
    }

    @objc private func willResignActive() {
        guard let forwardItems = forwardItems else {
            SentrySDKLog.warning("ForwardItems is nil. Can't forward items.")
            return
        }
        forwardItems()
    }

    @objc private func willTerminate() {
        guard let forwardItems = forwardItems else {
            SentrySDKLog.warning("ForwardItems is nil. Can't forward items.")
            return
        }
        forwardItems()
    }

    deinit {
        notificationCenter.removeObserver(
            self,
            name: CrossPlatformApplication.willResignActiveNotification,
            object: nil
        )

        notificationCenter.removeObserver(
            self,
            name: CrossPlatformApplication.willTerminateNotification,
            object: nil
        )
        self.forwardItems = nil
    }

}

#endif

// swiftlint:enable missing_docs
