#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI
import UIKit

struct SentryFeedbackFormRepresentable: UIViewControllerRepresentable {
    let configuration: SentryUserFeedbackConfiguration
    let delegate: SentryUserFeedbackFormDelegate
    let screenshot: UIImage?

    func makeUIViewController(context: Context) -> SentryUserFeedbackFormController {
        return SentryUserFeedbackFormController(config: configuration, delegate: delegate, screenshot: screenshot)
    }

    func updateUIViewController(_ uiViewController: SentryUserFeedbackFormController, context: Context) { }
}
#endif
