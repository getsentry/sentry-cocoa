#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)

@_spi(Private) @testable import Sentry
import UIKit

@_spi(Private) public class TestSentryViewRenderer: NSObject, SentryViewRenderer {
    /// Records invocations of `render(view:)`.
    public let renderInvocations: Invocations<WeakReference<UIView>> = Invocations()

    /// The value to be returned by `render(view:)`. If `nil`, `render(view:)` will fail with a precondition failure.
    public var mockedReturnValue: UIImage?

    /// An optional closure that gets called when `render(view:)` is invoked.
    ///
    /// Can be used to inspect the view passed to `render(view:)`.
    public var onRender: ((UIView) -> Void)?

    public func render(view: UIView) -> UIImage {
        renderInvocations.record(WeakReference(value: view))
        onRender?(view)
        guard let mockedReturnValue = mockedReturnValue else {
            preconditionFailure("TestSentryViewRendererV2: No mocked return value set for render(view:)")
        }
        return mockedReturnValue
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
