import SentryTestMock
import Swift

/// A helper class used to mock the ``SentryThreadInspector`` class.
///
/// - Warning: It might be incomplete, so make sure to implement the necessary methods when writing tests.
public class MockSentryThreadInspector: SentryThreadInspector, SentryMockable {
    public init() {
        super.init(options: Options())
    }

    // MARK: - Mock Helpers

    public func clearAllMocks() {
        // replace me
    }

    // MARK: - Mock Functions

    // replace me

    // MARK: - Override Functions

    // replace me
}
