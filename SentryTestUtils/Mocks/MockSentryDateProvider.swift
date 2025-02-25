import _SentryPrivate
@testable import Sentry
import SentryTestMock

/// A helper class used to mock the protocol ``SentryCurrentDateProvider``.
///
/// - Warning: It might be incomplete, so make sure to implement the necessary methods when writing tests.
public class MockSentryCurrentDateProvider: SentryCurrentDateProvider, SentryMockable {
    public init() {}

    // MARK: - Mock Helpers

    public func clearAllMocks() {
        mockDate.clear()
    }

    // MARK: - Mock Functions

    public var mockDate = MockFunction0<Date>()
    public var mockTimezoneOffset = MockFunction0<Int>()
    public var mockSystemTime = MockFunction0<UInt64>()
    public var mockSystemUptime = MockFunction0<TimeInterval>()

    // MARK: - Override Functions

    public func date() -> Date {
        mockDate.call(default: Date())
    }

    public func timezoneOffset() -> Int {
        mockTimezoneOffset.call(default: TimeZone.current.secondsFromGMT())
    }

    public func systemTime() -> UInt64 {
        mockSystemTime.call(default: getAbsoluteTime())
    }

    public func systemUptime() -> TimeInterval {
        mockSystemUptime.call(default: ProcessInfo.processInfo.systemUptime)
    }
}
