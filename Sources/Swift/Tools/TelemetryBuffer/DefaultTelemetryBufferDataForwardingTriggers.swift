// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
private typealias CrossPlatformApplication = UIApplication
#elseif os(macOS) && !SENTRY_NO_UI_FRAMEWORK
import AppKit
private typealias CrossPlatformApplication = NSApplication
#endif

protocol TelemetryBufferItemForwardingDelegate: AnyObject {
    func forwardItems()
}

protocol TelemetryBufferItemForwardingTriggers {
    /// Sets the delegate to be invoked on app lifecycle events.
    /// - Parameter delegate: The delegate instance, or nil to unregister
    /// - Important: Only supports ONE delegate per instance. Multiple calls will replace the previous delegate.
    func setDelegate(_ delegate: TelemetryBufferItemForwardingDelegate?)
}

struct NoOpTelemetryBufferDataForwardingTriggers: TelemetryBufferItemForwardingTriggers {
    func setDelegate(_ delegate: TelemetryBufferItemForwardingDelegate?) {
        // Empty on purpose - ignore delegate assignment
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
    private weak var delegate: TelemetryBufferItemForwardingDelegate?

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

    func setDelegate(_ delegate: TelemetryBufferItemForwardingDelegate?) {
        self.delegate = delegate
    }

    @objc private func willResignActive() {
        guard let delegate = delegate else {
            SentrySDKLog.warning("Delegate is nil. Can't forward items.")
            return
        }
        delegate.forwardItems()
    }

    @objc private func willTerminate() {
        guard let delegate = delegate else {
            SentrySDKLog.warning("Delegate is nil. Can't forward items.")
            return
        }
        delegate.forwardItems()
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
        self.delegate = nil
    }

}

#else
/// No-op version for platforms without UI framework support
typealias DefaultTelemetryBufferDataForwardingTriggers = NoOpTelemetryBufferDataForwardingTriggers
#endif

// swiftlint:enable missing_docs
