#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI
import UIKit

/// A SwiftUI wrapper that displays the Sentry user feedback form.
///
/// Use this view from a SwiftUI presentation container, such as `.sheet`.
@available(iOSApplicationExtension, unavailable)
public struct SentryUserFeedbackFormView: UIViewControllerRepresentable {
    private let image: UIImage?

    /// Creates a feedback form using the global configuration from `SentryOptions.configureUserFeedback`.
    /// - Parameter image: An optional image to attach to the feedback form.
    public init(image: UIImage? = nil) {
        self.image = image
    }

    // swiftlint:disable:next missing_docs
    public func makeUIViewController(context: Context) -> SentryUserFeedbackFormController {
        return SentryUserFeedbackFormController(image: image)
    }

    // swiftlint:disable:next missing_docs
    public func updateUIViewController(_ uiViewController: SentryUserFeedbackFormController, context: Context) { }
}

/// SwiftUI aliases for Sentry SDK feedback APIs.
public extension SentrySDK {
    /// A SwiftUI view that displays the Sentry user feedback form.
    typealias FeedbackFormView = SentryUserFeedbackFormView
}
#endif
