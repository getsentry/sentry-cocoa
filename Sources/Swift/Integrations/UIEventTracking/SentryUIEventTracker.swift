@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

private let sentryUIEventTrackerSwizzleSendAction = "SentryUIEventTrackerSwizzleSendAction"

/// Tracks UIKit control actions and forwards normalized UI events to a tracker mode.
@_spi(Private)
@objc(SentryUIEventTracker)
public final class SentryUIEventTracker: NSObject {
    private let uiEventTrackerMode: any SentryUIEventTrackerMode
    private let reportAccessibilityIdentifier: Bool

    /// Creates a UI event tracker with the given mode.
    @objc(initWithMode:reportAccessibilityIdentifier:)
    public init(mode: any SentryUIEventTrackerMode, reportAccessibilityIdentifier: Bool) {
        self.uiEventTrackerMode = mode
        self.reportAccessibilityIdentifier = reportAccessibilityIdentifier
        super.init()
    }

    /// Starts tracking UIKit send action events.
    @objc public func start() {
        SentryDependencyContainer.sharedInstance().swizzleWrapper.swizzleSendAction({ [weak self] action, target, sender, event in
            self?.sendActionCallback(action: action, target: target, sender: sender, event: event)
        }, forKey: sentryUIEventTrackerSwizzleSendAction)
    }

    /// Stops tracking UIKit send action events.
    @objc public func stop() {
        SentryDependencyContainer.sharedInstance().swizzleWrapper.removeSwizzleSendAction(forKey: sentryUIEventTrackerSwizzleSendAction)
    }

    /// Returns whether the operation belongs to an automatic UI event transaction.
    @objc public static func isUIEventOperation(_ operation: String) -> Bool {
        return operation == SentrySpanOperationUiAction || operation == SentrySpanOperationUiActionClick
    }

    private func sendActionCallback(action: String, target: Any?, sender: Any?, event: UIEvent?) {
        guard let target else {
            SentrySDKLog.debug("Target was nil for action \(action); won't capture in transaction (sender: \(String(describing: sender)); event: \(String(describing: event)))")
            return
        }

        guard let sender else {
            SentrySDKLog.debug("Sender was nil for action \(action); won't capture in transaction (target: \(target); event: \(String(describing: event)))")
            return
        }

        let targetObject = target as AnyObject
        let targetClass = NSStringFromClass(type(of: targetObject))
        if targetClass.contains("SwiftUI") {
            SentrySDKLog.debug("Won't record transaction for SwiftUI target event.")
            return
        }

        let actionName = transactionName(action: action, target: targetClass)
        let operation = Self.operation(sender: sender)

        let accessibilityIdentifier: String?
        if reportAccessibilityIdentifier, let view = sender as? UIView {
            accessibilityIdentifier = view.accessibilityIdentifier
        } else {
            accessibilityIdentifier = nil
        }

        uiEventTrackerMode.handleUIEvent(
            actionName,
            operation: operation,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    private static func operation(sender: Any) -> String {
        if sender is UIButton || sender is UIBarButtonItem || sender is UISegmentedControl || sender is UIPageControl {
            return SentrySpanOperationUiActionClick
        }

        return SentrySpanOperationUiAction
    }

    private func transactionName(action: String, target: String) -> String {
        let components = action.components(separatedBy: ":")
        guard components.count > 2 else {
            return "\(target).\(components.first ?? "")"
        }

        let arguments = components.dropFirst().dropLast().map { "\($0):" }.joined()
        return "\(target).\(components.first ?? "")(\(arguments))"
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
