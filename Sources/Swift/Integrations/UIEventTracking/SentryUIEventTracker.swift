@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// Tracks UIKit control actions and forwards normalized UI events to a tracker mode.
final class SentryUIEventTracker {

    // MARK: - Types

    struct Options {
        let reportAccessibilityIdentifier: Bool
    }

    /// Receives normalized UI event actions from `SentryUIEventTracker`.
    protocol EventProcessor {
        /// Handles a tracked UI event action.
        func handleUIEvent(_ action: String, operation: String, accessibilityIdentifier: String?)
    }

    // MARK: - Constants

    private static let sentryUIEventTrackerSwizzleSendAction = "SentryUIEventTrackerSwizzleSendAction"

    // MARK: - Properties

    private let swizzleWrapper: SentrySwizzleWrapperProtocol
    private let eventProcessor: EventProcessor
    private let options: Options

    /// Creates a UI event tracker with the given mode.
    public init(options: Options, eventProcessor: EventProcessor, swizzleWrapper: SentrySwizzleWrapperProtocol) {
        self.options = options
        self.eventProcessor = eventProcessor
        self.swizzleWrapper = swizzleWrapper
    }

    /// Starts tracking UIKit send action events.
    func start() {
        swizzleWrapper.swizzleSendAction({ [weak self] action, target, sender, event in
            self?.sendActionCallback(action: action, target: target, sender: sender, event: event)
        }, forKey: Self.sentryUIEventTrackerSwizzleSendAction)
    }

    /// Stops tracking UIKit send action events.
    func stop() {
        swizzleWrapper.removeSwizzleSendAction(forKey: Self.sentryUIEventTrackerSwizzleSendAction)
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
        if options.reportAccessibilityIdentifier, let view = sender as? UIView {
            accessibilityIdentifier = view.accessibilityIdentifier
        } else {
            accessibilityIdentifier = nil
        }

        eventProcessor.handleUIEvent(
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
