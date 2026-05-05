#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import Foundation
import SwiftUI
import UIKit

struct SentryFeedbackFormRepresentable: UIViewControllerRepresentable {
    let configuration: SentryUserFeedbackConfiguration
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> SentryUserFeedbackFormController {
        // swiftlint:disable:next todo
        // TODO: Decide how SwiftUI presentations should handle screenshots.
        return SentryUserFeedbackFormController(config: configuration, delegate: context.coordinator, screenshot: nil)
    }

    func updateUIViewController(_ uiViewController: SentryUserFeedbackFormController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        return Coordinator(isPresented: $isPresented)
    }

    final class Coordinator: NSObject, SentryUserFeedbackFormDelegate {
        @Binding private var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
            super.init()
        }

        func finished(with feedback: SentryFeedback?) {
            if let feedback = feedback {
                SentrySDK.capture(feedback: feedback)
            }
            isPresented = false
        }
    }
}
#endif
