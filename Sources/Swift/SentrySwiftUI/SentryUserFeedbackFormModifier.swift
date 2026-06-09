#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI
import UIKit

@available(iOSApplicationExtension, unavailable)
struct SentryUserFeedbackFormModifier: ViewModifier {
    @Binding var isPresented: Bool
    let screenshot: UIImage?
    let configure: SentryUserFeedbackConfigurationCallback?

    func body(content: Content) -> some View {
        return content.sheet(isPresented: $isPresented) {
            SentrySDK.FeedbackFormView(screenshot: screenshot, configure: configure)
        }
    }
}

/// nodoc
public extension View {
    /// Presents the Sentry user feedback form using a SwiftUI sheet, screenshot attachment, and optional form-specific configuration.
    ///
    /// Per-presentation configuration only affects the displayed form. Widget, custom button,
    /// screenshot trigger, and shake gesture settings are global and ignored for individual presentations.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - Parameters:
    ///   - isPresented: A binding that controls whether the feedback form is presented.
    ///   - screenshot: An optional screenshot to attach to the feedback form.
    ///   - configure: A closure to customize this feedback form presentation.
    /// - Returns: A view that presents the feedback form when `isPresented` is `true`.
    @available(iOSApplicationExtension, unavailable)
    func sentryFeedback(
        isPresented: Binding<Bool>,
        screenshot: UIImage? = nil,
        configure: SentryUserFeedbackConfigurationCallback? = nil
    ) -> some View {
        return modifier(SentryUserFeedbackFormModifier(
            isPresented: isPresented,
            screenshot: screenshot,
            configure: configure))
    }
}
#endif
