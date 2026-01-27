import Foundation
@_spi(Private) @testable import Sentry

@_spi(Private) public class TestEventContextEnricher: SentryEventContextEnricher {
    public init() {}

    public var enrichWithAppStateInvocations = Invocations<[String: Any]>()
    public var enrichWithAppStateReturnValue: [String: Any]?

    public func enrichWithAppState(_ context: [String: Any]) -> [String: Any] {
        enrichWithAppStateInvocations.record(context)
        return enrichWithAppStateReturnValue ?? context
    }
}
