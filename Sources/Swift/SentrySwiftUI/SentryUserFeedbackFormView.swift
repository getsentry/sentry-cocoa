#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI
import UIKit

/// A SwiftUI wrapper that displays the Sentry user feedback form.
///
/// Use this view from a SwiftUI presentation container, such as `.sheet`.
@available(iOSApplicationExtension, unavailable)
public struct SentryUserFeedbackFormView: UIViewControllerRepresentable {
    private let config: SentryUserFeedbackConfiguration
    private let image: UIImage?

    /// Creates a feedback form with the specified configuration and image attachment.
    /// - Parameters:
    ///   - config: The configuration for this feedback form instance.
    ///   - image: An optional image to attach to the feedback form.
    public init(config: SentryUserFeedbackConfiguration, image: UIImage? = nil) {
        self.config = config
        self.image = image
    }

    // swiftlint:disable:next missing_docs
    public func makeUIViewController(context: Context) -> SentryUserFeedbackFormController {
        return SentryUserFeedbackFormController(config: config, image: image)
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
