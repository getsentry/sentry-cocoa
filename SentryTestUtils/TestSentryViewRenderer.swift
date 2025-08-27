#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_spi(Private) @testable import Sentry
import UIKit

@_spi(Private) public class TestSentryViewRenderer: NSObject, SentryViewRenderer {
    let renderInvocations: Invocations<WeakReference<UIView>> = Invocations()
    var mockedReturnValue: UIImage?

    public func render(view: UIView) -> UIImage {
        renderInvocations.record(WeakReference(value: view))
        guard let mockedReturnValue = mockedReturnValue else {
            preconditionFailure("TestSentryViewRendererV2: No mocked return value set for render(view:)")
        }
        return mockedReturnValue
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
