#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import Foundation
import SwiftUI
import UIKit

struct SentryFeedbackFormRepresentable: UIViewControllerRepresentable {
    let driver: SentryUserFeedbackIntegrationDriver
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> SentryUserFeedbackFormController {
        // swiftlint:disable:next todo
        // TODO: Decide how SwiftUI presentations should handle screenshots.
        return SentryUserFeedbackFormController(config: driver.configuration, delegate: context.coordinator, screenshot: nil)
    }

    func updateUIViewController(_ uiViewController: SentryUserFeedbackFormController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        return Coordinator(driver: driver, isPresented: $isPresented)
    }

    final class Coordinator: NSObject, SentryUserFeedbackFormDelegate {
        private weak var driver: SentryUserFeedbackIntegrationDriver?
        @Binding private var isPresented: Bool

        init(driver: SentryUserFeedbackIntegrationDriver, isPresented: Binding<Bool>) {
            self.driver = driver
            _isPresented = isPresented
            super.init()
        }

        func didShow() {
            driver?.formDidOpen()
        }

        func finished(with feedback: SentryFeedback?) {
            driver?.formDidFinish(feedback: feedback)
            isPresented = false
        }
    }
}
#endif
