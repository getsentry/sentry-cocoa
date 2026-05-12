#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI
import UIKit

@available(iOSApplicationExtension, unavailable)
final class SentrySwiftUIFeedbackFormPresenter: ObservableObject, SentryFeedbackFormPresenter {
    weak var delegate: SentryFeedbackFormPresenterDelegate?

    private(set) var activeScreenshot: UIImage?
    private var isPresented: Binding<Bool>?
    private var didNotifyDismissal = false

    func update(isPresented: Binding<Bool>) {
        self.isPresented = isPresented
    }

    @discardableResult
    func present(screenshot: UIImage?) -> Bool {
        didNotifyDismissal = false

        guard let isPresented = isPresented else {
            SentrySDKLog.debug("Cannot show feedback form — SwiftUI presenter is not attached")
            return false
        }

        guard !isPresented.wrappedValue else {
            SentrySDKLog.debug("Cannot show feedback form — SwiftUI sheet is already displayed")
            return false
        }

        activeScreenshot = screenshot
        isPresented.wrappedValue = true
        return true
    }

    func dismiss() {
        guard let isPresented = isPresented else {
            notifyDismissed()
            return
        }

        guard isPresented.wrappedValue else {
            notifyDismissed()
            return
        }

        isPresented.wrappedValue = false
    }

    func sheetDidDismiss() {
        notifyDismissed()
    }

    private func notifyDismissed() {
        guard !didNotifyDismissal else { return }
        didNotifyDismissal = true
        activeScreenshot = nil
        delegate?.feedbackFormPresenterDidDismiss(self)
    }
}
#endif
