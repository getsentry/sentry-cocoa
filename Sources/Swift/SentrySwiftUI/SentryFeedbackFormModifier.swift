#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI

private struct SentryFeedbackFormModifier: ViewModifier {
    @State private var isPresented = false

    private var driver: SentryUserFeedbackIntegrationDriver? {
        SentryFeedbackAPI.getIntegration()?.driver
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                driver?.setSwiftUIPresenter { driver in
                    present(using: driver)
                }
            }
            .onDisappear {
                driver?.setSwiftUIPresenter(nil)
            }
            .sheet(isPresented: $isPresented, onDismiss: finishDismissal) {
                if let driver = driver {
                    SentryFeedbackFormRepresentable(driver: driver, isPresented: $isPresented)
                }
            }
    }

    @discardableResult
    private func present(using driver: SentryUserFeedbackIntegrationDriver) -> Bool {
        guard !isPresented else { return false }
        guard driver.beginPresentation(.swiftUI) else { return false }

        isPresented = true
        return true
    }

    private func finishDismissal() {
        driver?.finishPresentation()
        isPresented = false
    }
}

/// nodoc
public extension View {
    /// Registers this view as the SwiftUI presenter for `SentrySDK.feedback.presentForm()`.
    ///
    /// Apply this near the root of a SwiftUI app to make the convenience API use SwiftUI sheet presentation.
    /// - Returns: A view that can present the Sentry-managed feedback form for global feedback presentation requests.
    /// - Experiment: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    func sentryFeedbackForm() -> some View {
        modifier(SentryFeedbackFormModifier())
    }

}
#endif
