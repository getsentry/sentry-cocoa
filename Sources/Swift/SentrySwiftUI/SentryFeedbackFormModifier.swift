#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI

private struct SentryFeedbackFormModifier: ViewModifier {
    @Binding private var isPresented: Bool
    private let registersGlobalPresenter: Bool
    @State private var presentedDriver: SentryUserFeedbackIntegrationDriver?

    init(isPresented: Binding<Bool>, registersGlobalPresenter: Bool = false) {
        _isPresented = isPresented
        self.registersGlobalPresenter = registersGlobalPresenter
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                if registersGlobalPresenter {
                    SentryFeedbackAPI.getIntegration()?.driver.setSwiftUIPresenter { driver in
                        present(using: driver)
                    }
                }
                if isPresented {
                    presentFromBinding()
                }
            }
            .onDisappear {
                if registersGlobalPresenter {
                    SentryFeedbackAPI.getIntegration()?.driver.setSwiftUIPresenter(nil)
                }
            }
            .onChange(of: isPresented) { newValue in
                if newValue {
                    presentFromBinding()
                } else {
                    presentedDriver?.finishPresentation()
                }
            }
            .sheet(isPresented: formBinding, onDismiss: finishDismissal) {
                if let presentedDriver = presentedDriver {
                    SentryFeedbackFormRepresentable(driver: presentedDriver, isPresented: formBinding)
                }
            }
    }

    private var formBinding: Binding<Bool> {
        Binding(
            get: { presentedDriver?.isPresenting(.swiftUI) == true },
            set: { isPresented in
                if !isPresented {
                    presentedDriver?.finishPresentation()
                }
            })
    }

    private func presentFromBinding() {
        guard let driver = SentryFeedbackAPI.getIntegration()?.driver else {
            SentrySDKLog.debug("Cannot show feedback form — user feedback integration is not installed")
            isPresented = false
            return
        }

        if !present(using: driver) {
            isPresented = false
        }
    }

    @discardableResult
    private func present(using driver: SentryUserFeedbackIntegrationDriver) -> Bool {
        guard presentedDriver == nil else { return false }
        guard driver.beginPresentation(.swiftUI) else { return false }

        presentedDriver = driver
        return true
    }

    private func finishDismissal() {
        presentedDriver?.finishPresentation()
        presentedDriver = nil
        isPresented = false
    }
}

/// nodoc
public extension View {
    /// Presents the Sentry-managed feedback form when the binding becomes `true`.
    ///
    /// Use this when your SwiftUI view owns the feedback trigger.
    /// - Parameter isPresented: A binding controlling whether the feedback form is presented.
    /// - Returns: A view that presents the feedback form using SwiftUI sheet presentation.
    /// - Experiment: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    func sentryFeedbackForm(isPresented: Binding<Bool>) -> some View {
        modifier(SentryFeedbackFormModifier(isPresented: isPresented))
    }

    /// Registers this view as the SwiftUI presenter for `SentrySDK.feedback.presentForm()`.
    ///
    /// Apply this near the root of a SwiftUI app to make the convenience API use SwiftUI sheet presentation.
    /// - Returns: A view that can present the Sentry-managed feedback form for global feedback presentation requests.
    /// - Experiment: This is an experimental feature and may still have bugs.
    @available(iOSApplicationExtension, unavailable)
    func sentryFeedbackPresenter() -> some View {
        modifier(SentryFeedbackFormModifier(isPresented: .constant(false), registersGlobalPresenter: true))
    }

}
#endif
