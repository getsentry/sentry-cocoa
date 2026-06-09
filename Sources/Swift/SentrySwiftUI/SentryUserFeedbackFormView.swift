#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI
import UIKit

/// A SwiftUI wrapper that displays the Sentry user feedback form.
///
/// Use this view from a SwiftUI presentation container, such as `.sheet`.
///
/// - warning: This is an experimental feature and may still have bugs.
@available(iOSApplicationExtension, unavailable)
public struct SentryUserFeedbackFormView: UIViewControllerRepresentable {
    private let screenshot: UIImage?

    /// Creates a feedback form using the global configuration from `SentryOptions.configureUserFeedback`.
    /// - Parameter screenshot: An optional screenshot to attach to the feedback form.
    /// - warning: This is an experimental feature and may still have bugs.
    public init(screenshot: UIImage? = nil) {
        self.screenshot = screenshot
    }

    // swiftlint:disable:next missing_docs
    public func makeUIViewController(context: Context) -> SentryUserFeedbackFormController {
        let controller = SentryUserFeedbackFormController(screenshot: screenshot)
        // SwiftUI sheets keep the hosting controller's view visible behind the wrapped view controller's
        // bottom safe area. Match that parent background to the form after SwiftUI attaches the controller.
        controller.didMoveToParent = { controller in
            updateParentBackgroundColor(for: controller)
        }
        return controller
    }

    // swiftlint:disable:next missing_docs
    public func updateUIViewController(_ uiViewController: SentryUserFeedbackFormController, context: Context) { }

    private func updateParentBackgroundColor(for controller: SentryUserFeedbackFormController) {
        guard let parent = controller.parent else { return }
        parent.view.backgroundColor = controller.view.backgroundColor
    }
}

/// SwiftUI aliases for Sentry SDK feedback APIs.
public extension SentrySDK {
    /// A SwiftUI view that displays the Sentry user feedback form.
    /// - warning: This is an experimental feature and may still have bugs.
    typealias FeedbackFormView = SentryUserFeedbackFormView
}
#endif
