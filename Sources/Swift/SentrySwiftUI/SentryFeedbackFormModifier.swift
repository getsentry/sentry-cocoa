#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI

private struct SentryFeedbackFormModifier: ViewModifier {
    @State private var isPresented = false
    @StateObject private var presenter = SentrySwiftUIFeedbackFormPresenter()

    private var driver: SentryUserFeedbackIntegrationDriver? {
        SentryFeedbackAPI.getIntegration()?.driver
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                presenter.update(isPresented: $isPresented)
                driver?.setFeedbackFormPresenter(presenter)
            }
            .onDisappear {
                driver?.removeFeedbackFormPresenter(presenter)
            }
            .sheet(isPresented: $isPresented, onDismiss: finishDismissal) {
                if let driver = driver {
                    SentryFeedbackFormRepresentable(
                        configuration: driver.configuration,
                        delegate: driver,
                        screenshot: presenter.activeScreenshot
                    )
                }
            }
    }

    private func finishDismissal() {
        presenter.sheetDidDismiss()
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
