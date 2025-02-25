import Sentry
import SentryTestMock

/// A helper class used to mock the ``SentryScope`` class.
///
/// - Warning: It might be incomplete, so make sure to implement the necessary methods when writing tests.
public class MockSentryScope: Scope, SentryMockable {
    // MARK: - Mock Helpers

    public func clearAllMocks() {
        mockUseSpan.clear()
    }

    // MARK: - Mock Functions

    public var mockUseSpan = MockFunction1<Void, SentrySpanCallback>()

    // MARK: - Overridden Functions

    public override func useSpan(_ callback: @escaping SentrySpanCallback) {
        mockUseSpan.call(callback, default: { arg1 in
            super.useSpan(arg1)
        })
    }
}
