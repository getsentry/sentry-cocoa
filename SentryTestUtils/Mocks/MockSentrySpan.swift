import Sentry
import SentryTestMock

/// A helper class used to mock the ``SentrySpan`` class.
///
/// - Warning: It might be incomplete, so make sure to implement the necessary methods when writing tests.
public class MockSentrySpan: SentrySpan, SentryMockable {
    public init() {
        #if canImport(UIKit)
        super.init(context: MockSpanContext(), framesTracker: nil)
        #else
        super.init(context: MockSpanContext())
        #endif
    }

    // MARK: - Mock Helpers

    public func clearAllMocks() {
        mockStartChildWithOperationDescription.clear()
    }

    // MARK: - Mock Functions

    public var mockStartChildWithOperationDescription = MockFunction2<Span, String, String?>()

    // MARK: - Override Functions

    public override func startChild(operation: String, description: String?) -> any Span {
        mockStartChildWithOperationDescription.call(operation, description, default: { arg1, arg2 in
            super.startChild(operation: arg1, description: arg2)
        })
    }
}
