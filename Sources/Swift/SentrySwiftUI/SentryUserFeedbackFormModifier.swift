#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI
import UIKit

@available(iOSApplicationExtension, unavailable)
struct SentryUserFeedbackFormModifier: ViewModifier {
    @Binding var isPresented: Bool
    let image: UIImage?

    func body(content: Content) -> some View {
        return content.sheet(isPresented: $isPresented) {
            SentrySDK.FeedbackFormView(image: image)
        }
    }
}

/// nodoc
public extension View {
    /// Presents the Sentry user feedback form using a SwiftUI sheet.
    ///
    /// - Parameters:
    ///   - isPresented: A binding that controls whether the feedback form is presented.
    ///   - image: An optional image to attach to the feedback form.
    /// - Returns: A view that presents the feedback form when `isPresented` is `true`.
    @available(iOSApplicationExtension, unavailable)
    func sentryFeedback(isPresented: Binding<Bool>, image: UIImage? = nil) -> some View {
        return modifier(SentryUserFeedbackFormModifier(isPresented: isPresented, image: image))
    }
}
#endif
