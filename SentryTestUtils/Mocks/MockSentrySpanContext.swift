import Sentry
import SentryTestMock

/// A helper class used to mock the ``SpanContext`` class.
///
/// - Warning: It might be incomplete, so make sure to implement the necessary methods when writing tests.
public class MockSpanContext: SpanContext, SentryMockable {
    public init() {
        super.init(
            trace: SentryId(uuidString: "f00df00df00df00df00df00df00df00d"),
            spanId: SpanId(value: "baadbaadbaadbaadba"),
            parentId: nil,
            operation: "mock.operation",
            spanDescription: nil,
            sampled: .undecided
        )
    }

    // MARK: - Mock Helpers

    public func clearAllMocks() {}

    // MARK: - Mock Functions

    // replace me

    // MARK: - Override Functions

    // replace me
}
